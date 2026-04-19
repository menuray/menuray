import type { LlmProvider, MenuDraft, OcrResult } from "./types.ts";

const FIXTURE_URL = new URL(
  "../../parse-menu/fixtures/yun_jian_xiao_chu.json",
  import.meta.url,
);

type Fixture = { menu_draft: MenuDraft };

let cachedFixture: Fixture | null = null;

async function loadFixture(): Promise<Fixture> {
  if (cachedFixture) return cachedFixture;
  const text = await Deno.readTextFile(FIXTURE_URL);
  cachedFixture = JSON.parse(text) as Fixture;
  return cachedFixture;
}

export class MockLlmProvider implements LlmProvider {
  readonly name = "mock";

  async structure(
    _ocr: OcrResult,
    _hints: { sourceLocale?: string; currency?: string },
  ): Promise<MenuDraft> {
    await new Promise((resolve) => setTimeout(resolve, 0));
    const { menu_draft } = await loadFixture();
    return menu_draft;
  }
}
