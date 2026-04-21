// ============================================================================
// Thin wrapper over OpenAI's Chat Completions endpoint. One retry on 5xx /
// network failure with 2s delay. 45s per-call timeout via AbortController.
// 4xx (including 429) fails immediately.
// ============================================================================

const OPENAI_URL = "https://api.openai.com/v1/chat/completions";
const TIMEOUT_MS = 45_000;
const RETRY_DELAY_MS = 2_000;

export type ChatRequest = {
  model: string;
  messages: unknown[];
  response_format?: unknown;
  max_tokens?: number;
};

export async function chatCompletion(req: ChatRequest): Promise<unknown> {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) throw new Error("OPENAI_API_KEY not set");

  try {
    return await callOnce(req, apiKey);
  } catch (e) {
    if (!isRetryable(e)) throw e;
    await sleep(RETRY_DELAY_MS);
    return await callOnce(req, apiKey);
  }
}

async function callOnce(req: ChatRequest, apiKey: string): Promise<unknown> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const resp = await fetch(OPENAI_URL, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(req),
    });
    if (resp.status >= 500) {
      const body = await resp.text();
      throw new RetryableError(`OpenAI 5xx ${resp.status}: ${body}`);
    }
    if (!resp.ok) {
      const body = await resp.text();
      throw new Error(`OpenAI ${resp.status}: ${body}`);
    }
    return await resp.json();
  } finally {
    clearTimeout(timer);
  }
}

class RetryableError extends Error {
  constructor(msg: string) {
    super(msg);
    this.name = "RetryableError";
  }
}

function isRetryable(e: unknown): boolean {
  if (e instanceof RetryableError) return true;
  if (e instanceof Error) {
    // AbortError (timeout) or TypeError (network failure) are retryable.
    if (e.name === "AbortError") return true;
    if (e.name === "TypeError") return true;
  }
  return false;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
