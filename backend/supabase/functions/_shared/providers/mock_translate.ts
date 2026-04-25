// Deterministic stub used in CI + local dev. Each translated string is
// `[locale] <source>` so tests can assert exact output without real LLM calls.

import type {
  TranslateInput,
  TranslateOutput,
  TranslateProvider,
} from "./types.ts";

export class MockTranslateProvider implements TranslateProvider {
  readonly name = "mock";

  translate(input: TranslateInput, targetLocale: string): Promise<TranslateOutput> {
    return Promise.resolve({
      categories: input.categories.map((c) => ({
        id: c.id,
        name: `[${targetLocale}] ${c.sourceName}`,
      })),
      dishes: input.dishes.map((d) => ({
        id: d.id,
        name: `[${targetLocale}] ${d.sourceName}`,
        description: `[${targetLocale}] ${d.sourceDescription ?? ""}`,
      })),
    });
  }
}
