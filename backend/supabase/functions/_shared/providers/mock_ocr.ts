import type { OcrProvider, OcrResult } from "./types.ts";

// Read fixture at module init time. Deno supports static fixture paths
// relative to the module URL.
const FIXTURE_URL = new URL(
  "../../parse-menu/fixtures/yun_jian_xiao_chu.json",
  import.meta.url,
);

type Fixture = { ocr: OcrResult };

let cachedFixture: Fixture | null = null;

async function loadFixture(): Promise<Fixture> {
  if (cachedFixture) return cachedFixture;
  const text = await Deno.readTextFile(FIXTURE_URL);
  cachedFixture = JSON.parse(text) as Fixture;
  return cachedFixture;
}

export class MockOcrProvider implements OcrProvider {
  readonly name = "mock";

  async extract(_photoUrls: string[]): Promise<OcrResult> {
    await new Promise((resolve) => setTimeout(resolve, 0));
    const { ocr } = await loadFixture();
    return ocr;
  }
}
