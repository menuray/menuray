// ============================================================================
// Provider interfaces and shared DTOs for the parse-menu pipeline.
// See docs/superpowers/specs/2026-04-19-supabase-backend-mvp-design.md §7.
// ============================================================================

export type OcrBlock = {
  text: string;
  bbox: [number, number, number, number]; // [x, y, w, h] normalized 0..1
};

export type OcrResult = {
  fullText: string;
  blocks: OcrBlock[];
  sourceLocale?: string;
};

export interface OcrProvider {
  readonly name: string;
  extract(photoUrls: string[]): Promise<OcrResult>;
}

export type SpiceLevel = "none" | "mild" | "medium" | "hot";
export type Confidence = "high" | "low";

export type MenuDraftDish = {
  sourceName: string;
  sourceDescription?: string;
  price: number;
  position: number;
  spiceLevel: SpiceLevel;
  confidence: Confidence;
  isSignature: boolean;
  isRecommended: boolean;
  isVegetarian: boolean;
  allergens: string[];
};

export type MenuDraftCategory = {
  sourceName: string;
  position: number;
  dishes: MenuDraftDish[];
};

export type MenuDraft = {
  name: string;
  sourceLocale: string;
  currency: string; // ISO 4217
  categories: MenuDraftCategory[];
};

export interface LlmProvider {
  readonly name: string;
  structure(
    ocr: OcrResult,
    hints: { sourceLocale?: string; currency?: string },
  ): Promise<MenuDraft>;
}

// ============================================================================
// translate-menu (Session 7) — batched per-menu translation. Source-locale
// strings come from `categories.source_name` + `dishes.source_name/description`;
// outputs are upserted into `category_translations` + `dish_translations`.
// ============================================================================

export type TranslateInputCategory = { id: string; sourceName: string };
export type TranslateInputDish = {
  id: string;
  sourceName: string;
  sourceDescription: string | null;
};

export type TranslateInput = {
  sourceLocale: string;
  categories: TranslateInputCategory[];
  dishes: TranslateInputDish[];
};

export type TranslateOutputCategory = { id: string; name: string };
export type TranslateOutputDish = {
  id: string;
  name: string;
  description: string;
};

export type TranslateOutput = {
  categories: TranslateOutputCategory[];
  dishes: TranslateOutputDish[];
};

export interface TranslateProvider {
  readonly name: string;
  translate(input: TranslateInput, targetLocale: string): Promise<TranslateOutput>;
}

// ============================================================================
// ai-optimize (Session 7) — batched description rewrite. Operates only on
// `dishes.source_description`; the source name is left untouched.
// ============================================================================

export type OptimizeInputDish = {
  id: string;
  sourceName: string;
  sourceDescription: string | null;
};

export type OptimizeOutputDish = {
  id: string;
  description: string;
};

export interface OptimizeProvider {
  readonly name: string;
  optimize(
    dishes: OptimizeInputDish[],
    hints: { sourceLocale: string },
  ): Promise<OptimizeOutputDish[]>;
}
