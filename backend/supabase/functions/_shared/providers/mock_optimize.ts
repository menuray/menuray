// Deterministic stub used in CI + local dev. Appends "(rewritten)" so tests
// can assert exact output without real LLM calls.

import type {
  OptimizeInputDish,
  OptimizeOutputDish,
  OptimizeProvider,
} from "./types.ts";

export class MockOptimizeProvider implements OptimizeProvider {
  readonly name = "mock";

  optimize(
    dishes: OptimizeInputDish[],
    _hints: { sourceLocale: string },
  ): Promise<OptimizeOutputDish[]> {
    return Promise.resolve(
      dishes.map((d) => ({
        id: d.id,
        description: `${d.sourceDescription ?? d.sourceName} (rewritten)`,
      })),
    );
  }
}
