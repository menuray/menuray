// ============================================================================
// OpenAI provider for ai-optimize (Session 7) — rewrites dish source
// descriptions to be more enticing without inventing ingredients.
// ============================================================================
import type {
  OptimizeInputDish,
  OptimizeOutputDish,
  OptimizeProvider,
} from "./types.ts";
import { chatCompletion } from "./openai_client.ts";

const MODEL = "gpt-4o-mini";

const OPTIMIZE_SCHEMA = {
  name: "menu_optimize",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["dishes"],
    properties: {
      dishes: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["id", "description"],
          properties: {
            id: { type: "string" },
            description: { type: "string" },
          },
        },
      },
    },
  },
};

const SYSTEM_PROMPT =
  `You are a restaurant-menu copywriter. Rewrite each dish description to be
more enticing for a diner reading the menu, in the same source locale.

Rules:
- Preserve the input dish ids verbatim.
- Never invent ingredients or cooking methods that aren't in the original
  description or strongly implied by the dish name.
- Keep each description ≤ 2 short sentences. ~20-40 words.
- If the dish has no description, write a brief one based on the name and
  conventional cooking style.
- Match the source locale's idioms — translate nothing.
- Output ONLY JSON matching the provided schema. No prose.`;

type OpenAIChatResponse = { choices: Array<{ message: { content: string } }> };

export class OpenAIOptimizeProvider implements OptimizeProvider {
  readonly name = "openai-gpt-4o-mini";
  onRawResponse?: (raw: unknown) => void | Promise<void>;

  async optimize(
    dishes: OptimizeInputDish[],
    hints: { sourceLocale: string },
  ): Promise<OptimizeOutputDish[]> {
    const userMsg = `Source locale: ${hints.sourceLocale}

DISHES (id :: name :: description):
${
      dishes.map((d) =>
        `${d.id} :: ${d.sourceName} :: ${d.sourceDescription ?? ""}`
      ).join("\n")
    }`;

    const body = {
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMsg },
      ],
      response_format: { type: "json_schema", json_schema: OPTIMIZE_SCHEMA },
    };

    const resp = (await chatCompletion(body)) as OpenAIChatResponse;
    if (this.onRawResponse) {
      try {
        await this.onRawResponse(resp);
      } catch (e) {
        console.warn("openai_optimize.onRawResponse failed (non-fatal):", e);
      }
    }

    const parsed = JSON.parse(resp.choices[0].message.content) as {
      dishes: OptimizeOutputDish[];
    };
    return parsed.dishes;
  }
}
