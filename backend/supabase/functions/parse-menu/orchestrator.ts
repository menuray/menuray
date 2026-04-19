import type { SupabaseClient } from "@supabase/supabase-js";
import type { LlmProvider, MenuDraft, OcrProvider } from "../_shared/providers/types.ts";
import { createServiceRoleClient } from "../_shared/db.ts";
import { getLlmProvider, getOcrProvider } from "../_shared/providers/factory.ts";

type ParseRunRow = {
  id: string;
  store_id: string;
  menu_id: string | null;
  source_photo_paths: string[];
  status: "pending" | "ocr" | "structuring" | "succeeded" | "failed";
};

async function fetchRun(db: SupabaseClient, runId: string): Promise<ParseRunRow> {
  const { data, error } = await db
    .from("parse_runs")
    .select("id, store_id, menu_id, source_photo_paths, status")
    .eq("id", runId)
    .single();
  if (error) throw new Error(`parse_runs.select failed: ${error.message}`);
  if (!data) throw new Error(`parse_runs row ${runId} not found`);
  return data as ParseRunRow;
}

async function updateRun(
  db: SupabaseClient,
  runId: string,
  patch: Record<string, unknown>,
): Promise<void> {
  const { error } = await db.from("parse_runs").update(patch).eq("id", runId);
  if (error) throw new Error(`parse_runs.update failed: ${error.message}`);
}

async function insertDraftMenu(
  db: SupabaseClient,
  storeId: string,
  draft: MenuDraft,
): Promise<string> {
  // Call the plpgsql function insert_menu_draft which inserts
  // menu + categories + dishes in a single transaction. See migration
  // 20260420000001_init_schema.sql for the function definition.
  const { data, error } = await db.rpc("insert_menu_draft", {
    p_store_id: storeId,
    p_draft: draft,
  });
  if (error) throw new Error(`insert_menu_draft rpc failed: ${error.message}`);
  if (!data) throw new Error("insert_menu_draft returned no menu id");
  return data as string;
}

export async function runParse(
  runId: string,
  opts: {
    db?: SupabaseClient;
    ocr?: OcrProvider;
    llm?: LlmProvider;
  } = {},
): Promise<ParseRunRow["status"]> {
  const db = opts.db ?? createServiceRoleClient();
  const ocr = opts.ocr ?? getOcrProvider();
  const llm = opts.llm ?? getLlmProvider();

  const run = await fetchRun(db, runId);

  // Idempotency: terminal states return immediately.
  if (run.status === "succeeded" || run.status === "failed") return run.status;

  let stage: "ocr" | "structure" = "ocr";
  try {
    await updateRun(db, runId, {
      status: "ocr",
      ocr_provider: ocr.name,
      started_at: new Date().toISOString(),
    });
    const ocrResult = await ocr.extract(run.source_photo_paths);

    stage = "structure";
    await updateRun(db, runId, {
      status: "structuring",
      llm_provider: llm.name,
    });
    const draft = await llm.structure(ocrResult, {
      sourceLocale: ocrResult.sourceLocale,
    });

    const menuId = await insertDraftMenu(db, run.store_id, draft);

    await updateRun(db, runId, {
      status: "succeeded",
      menu_id: menuId,
      finished_at: new Date().toISOString(),
    });
    return "succeeded";
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    await updateRun(db, runId, {
      status: "failed",
      error_stage: stage,
      error_message: message,
      finished_at: new Date().toISOString(),
    });
    return "failed";
  }
}
