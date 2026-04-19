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
