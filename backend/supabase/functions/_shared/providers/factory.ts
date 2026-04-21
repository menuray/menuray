import type { LlmProvider, OcrProvider } from "./types.ts";
import type { FactoryContext } from "./context.ts";
import { MockOcrProvider } from "./mock_ocr.ts";
import { MockLlmProvider } from "./mock_llm.ts";

export function getOcrProvider(_ctx?: FactoryContext): OcrProvider {
  const name = Deno.env.get("MENURAY_OCR_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockOcrProvider();
    // case "openai" wired in Task 7.
    default:
      throw new Error(`Unknown OCR provider: ${name}`);
  }
}

export function getLlmProvider(_ctx?: FactoryContext): LlmProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockLlmProvider();
    // case "openai" wired in Task 7.
    default:
      throw new Error(`Unknown LLM provider: ${name}`);
  }
}
