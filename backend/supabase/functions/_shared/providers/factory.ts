import type { LlmProvider, OcrProvider } from "./types.ts";
import type { FactoryContext } from "./context.ts";
import { MockOcrProvider } from "./mock_ocr.ts";
import { MockLlmProvider } from "./mock_llm.ts";
import { OpenAIOcrProvider } from "./openai_ocr.ts";
import { OpenAIStructureProvider } from "./openai_structure.ts";

export function getOcrProvider(ctx?: FactoryContext): OcrProvider {
  const name = Deno.env.get("MENURAY_OCR_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockOcrProvider();
    case "openai": {
      const p = new OpenAIOcrProvider(ctx?.supabase);
      if (ctx) p.onRawResponse = (raw) => persistRaw(ctx, "ocr_raw_response", raw);
      return p;
    }
    default:
      throw new Error(`Unknown OCR provider: ${name}`);
  }
}

export function getLlmProvider(ctx?: FactoryContext): LlmProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockLlmProvider();
    case "openai": {
      const p = new OpenAIStructureProvider();
      if (ctx) p.onRawResponse = (raw) => persistRaw(ctx, "llm_raw_response", raw);
      return p;
    }
    default:
      throw new Error(`Unknown LLM provider: ${name}`);
  }
}

async function persistRaw(
  ctx: FactoryContext,
  column: "ocr_raw_response" | "llm_raw_response",
  raw: unknown,
): Promise<void> {
  const { error } = await ctx.supabase
    .from("parse_runs")
    .update({ [column]: raw })
    .eq("id", ctx.runId);
  if (error) console.warn(`persistRaw(${column}) failed:`, error.message);
}
