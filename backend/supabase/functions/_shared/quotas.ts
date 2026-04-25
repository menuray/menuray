// AI batch quotas + locale caps shared by translate-menu + ai-optimize.
//
// Caps come from docs/product-decisions.md §2 (locale cap on customer view)
// and the Session 7 spec §4.3 (per-month batch quota).
//
// The locale cap counts every entry in menus.available_locales (which always
// includes the source locale), so Free's 2 means "source + 1 translation".

export type Tier = "free" | "pro" | "growth";

// Per-store, per-month batch operations (translate + optimize cumulative).
export const AI_BATCH_QUOTA: Record<Tier, number> = {
  free: 1,
  pro: 10,
  growth: 100,
};

// Per-menu max distinct locales in available_locales (incl. source).
export const LOCALE_CAP: Record<Tier, number> = {
  free: 2,
  pro: 5,
  growth: Number.POSITIVE_INFINITY,
};
