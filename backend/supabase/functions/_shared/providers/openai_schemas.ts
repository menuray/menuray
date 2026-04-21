// ============================================================================
// Strict JSON Schemas used as OpenAI response_format.json_schema. Mirror the
// TS types in ./types.ts so drift is visible. Note OpenAI strict mode requires
// every property in `required`; nullable fields use ['T', 'null'] union.
// ============================================================================

export const OCR_RESULT_SCHEMA = {
  name: "ocr_result",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["fullText", "blocks", "sourceLocale"],
    properties: {
      fullText: { type: "string" },
      blocks: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["text", "bbox"],
          properties: {
            text: { type: "string" },
            bbox: {
              type: "array",
              minItems: 4,
              maxItems: 4,
              items: { type: "number" },
            },
          },
        },
      },
      sourceLocale: {
        type: ["string", "null"],
        description: "ISO 639-1 language code of the menu, or null if not detectable.",
      },
    },
  },
} as const;

export const MENU_DRAFT_SCHEMA = {
  name: "menu_draft",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    required: ["name", "sourceLocale", "currency", "categories"],
    properties: {
      name: { type: "string" },
      sourceLocale: { type: "string" },
      currency: { type: "string" },
      categories: {
        type: "array",
        items: {
          type: "object",
          additionalProperties: false,
          required: ["sourceName", "position", "dishes"],
          properties: {
            sourceName: { type: "string" },
            position: { type: "integer" },
            dishes: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                required: [
                  "sourceName",
                  "sourceDescription",
                  "price",
                  "position",
                  "spiceLevel",
                  "confidence",
                  "isSignature",
                  "isRecommended",
                  "isVegetarian",
                  "allergens",
                ],
                properties: {
                  sourceName: { type: "string" },
                  sourceDescription: { type: ["string", "null"] },
                  price: { type: "number", minimum: 0 },
                  position: { type: "integer" },
                  spiceLevel: { enum: ["none", "mild", "medium", "hot"] },
                  confidence: { enum: ["high", "low"] },
                  isSignature: { type: "boolean" },
                  isRecommended: { type: "boolean" },
                  isVegetarian: { type: "boolean" },
                  allergens: { type: "array", items: { type: "string" } },
                },
              },
            },
          },
        },
      },
    },
  },
} as const;
