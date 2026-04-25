import type { SupabaseClient } from "@supabase/supabase-js";
import type { OptimizeProvider } from "../_shared/providers/types.ts";
import { getOptimizeProvider } from "../_shared/providers/factory.ts";
import { createServiceRoleClient } from "../_shared/db.ts";

type OptimizeResult = { rewrittenDishCount: number };

type DishRow = {
  id: string;
  source_name: string;
  source_description: string | null;
};

export async function runOptimize(
  menuId: string,
  opts: { db?: SupabaseClient; provider?: OptimizeProvider } = {},
): Promise<OptimizeResult> {
  const db = opts.db ?? createServiceRoleClient();
  const provider = opts.provider ?? getOptimizeProvider();

  const { data: menuRow, error: menuErr } = await db
    .from("menus")
    .select("id, source_locale")
    .eq("id", menuId)
    .maybeSingle();
  if (menuErr || !menuRow) {
    throw new Error(`menu lookup failed: ${menuErr?.message ?? "not found"}`);
  }
  const sourceLocale = (menuRow as { source_locale: string }).source_locale;

  const { data: dishes, error: dishErr } = await db
    .from("dishes")
    .select("id, source_name, source_description")
    .eq("menu_id", menuId);
  if (dishErr) throw new Error(`dishes.select failed: ${dishErr.message}`);
  const dishList = (dishes ?? []) as DishRow[];

  if (dishList.length === 0) {
    return { rewrittenDishCount: 0 };
  }

  const out = await provider.optimize(
    dishList.map((d) => ({
      id: d.id,
      sourceName: d.source_name,
      sourceDescription: d.source_description,
    })),
    { sourceLocale },
  );

  // Update each dish's source_description in turn. PostgREST doesn't support
  // multi-row UPDATE with row-specific values in one statement, so we issue
  // N parallel updates. This is fine for typical 30-200 dish menus.
  await Promise.all(out.map(async (d) => {
    const { error } = await db
      .from("dishes")
      .update({ source_description: d.description })
      .eq("id", d.id);
    if (error) throw new Error(`dishes.update ${d.id}: ${error.message}`);
  }));

  return { rewrittenDishCount: out.length };
}
