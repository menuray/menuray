// ============================================================================
// OpenAIStructureProvider equivalent for translate-menu (Session 7).
// Strict JSON Schema response_format; gpt-4o-mini.
// ============================================================================
import type {
  TranslateInput,
  TranslateOutput,
  TranslateProvider,
} from "./types.ts";
import { chatCompletion } from "./openai_client.ts";

const MODEL = "gpt-4o-mini";

const TRANSLATE_SCHEMA = {
  name: "menu_translation",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["categories", "dishes"],
    properties: {
      categories: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["id", "name"],
          properties: {
            id: { type: "string" },
            name: { type: "string" },
          },
        },
      },
      dishes: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["id", "name", "description"],
          properties: {
            id: { type: "string" },
            name: { type: "string" },
            description: { type: "string" },
          },
        },
      },
    },
  },
};

const SYSTEM_PROMPT =
  `You are a restaurant-menu translation engine. Translate every category
name, dish name, and dish description from the source locale into the target
locale.

Rules:
- Preserve the input ids verbatim; pair each translated entry with its source by id.
- Keep proper nouns and signature dish names recognisable when possible —
  English speakers searching for "Mapo Tofu" should still find it.
- Translate descriptive copy fully — don't drop ingredients or cooking style.
- For empty / null source descriptions, return an empty string.
- Output ONLY JSON matching the provided schema. No prose.`;

type OpenAIChatResponse = { choices: Array<{ message: { content: string } }> };

export class OpenAITranslateProvider implements TranslateProvider {
  readonly name = "openai-gpt-4o-mini";
  onRawResponse?: (raw: unknown) => void | Promise<void>;

  async translate(
    input: TranslateInput,
    targetLocale: string,
  ): Promise<TranslateOutput> {
    const userMsg = `Source locale: ${input.sourceLocale}
Target locale: ${targetLocale}

CATEGORIES (id :: source_name):
${input.categories.map((c) => `${c.id} :: ${c.sourceName}`).join("\n")}

DISHES (id :: source_name :: source_description):
${
      input.dishes.map((d) =>
        `${d.id} :: ${d.sourceName} :: ${d.sourceDescription ?? ""}`
      ).join("\n")
    }`;

    const body = {
      model: MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userMsg },
      ],
      response_format: { type: "json_schema", json_schema: TRANSLATE_SCHEMA },
    };

    const resp = (await chatCompletion(body)) as OpenAIChatResponse;
    if (this.onRawResponse) {
      try {
        await this.onRawResponse(resp);
      } catch (e) {
        console.warn("openai_translate.onRawResponse failed (non-fatal):", e);
      }
    }

    const parsed = JSON.parse(resp.choices[0].message.content) as TranslateOutput;
    return parsed;
  }
}
