import type { LlmProvider, OcrProvider } from "./types.ts";
import { MockOcrProvider } from "./mock_ocr.ts";
import { MockLlmProvider } from "./mock_llm.ts";

export function getOcrProvider(): OcrProvider {
  const name = Deno.env.get("MENURAY_OCR_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockOcrProvider();
    // case "google": return new GoogleVisionProvider();  // future session
    default:
      throw new Error(`Unknown OCR provider: ${name}`);
  }
}

export function getLlmProvider(): LlmProvider {
  const name = Deno.env.get("MENURAY_LLM_PROVIDER") ?? "mock";
  switch (name) {
    case "mock":
      return new MockLlmProvider();
    // case "anthropic": return new AnthropicLlmProvider();  // future session
    // case "openai":    return new OpenAiLlmProvider();     // future session
    default:
      throw new Error(`Unknown LLM provider: ${name}`);
  }
}
