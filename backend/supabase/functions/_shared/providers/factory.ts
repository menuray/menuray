import type {
  LlmProvider,
  OcrProvider,
  OptimizeProvider,
  TranslateProvider,
} from "./types.ts";
import type { FactoryContext } from "./context.ts";
import { MockOcrProvider } from "./mock_ocr.ts";
import { MockLlmProvider } from "./mock_llm.ts";
import { MockTranslateProvider } from "./mock_translate.ts";
import { MockOptimizeProvider } from "./mock_optimize.ts";
import { OpenAIOcrProvider } from "./openai_ocr.ts";
import { OpenAIStructureProvider } from "./openai_structure.ts";
import { OpenAITranslateProvider } from "./openai_translate.ts";
import { OpenAIOptimizeProvider } from "./openai_optimize.ts";

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

export function getTranslateProvider(): TranslateProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockTranslateProvider();
    case "openai":
      return new OpenAITranslateProvider();
    default:
      throw new Error(`Unknown translate provider: ${name}`);
  }
}

export function getOptimizeProvider(): OptimizeProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockOptimizeProvider();
    case "openai":
      return new OpenAIOptimizeProvider();
    default:
      throw new Error(`Unknown optimize provider: ${name}`);
  }
}
