export type Locale = string;  // 'en' | 'zh-CN' | 'ja' | …
export type SpiceLevel = 'none' | 'mild' | 'medium' | 'hot';
export type TimeSlot = 'all_day' | 'lunch' | 'dinner' | 'seasonal';

export type TemplateId = 'minimal' | 'grid' | 'bistro' | 'izakaya' | 'street';

export interface ThemeOverrides {
  primaryColor?: string;  // validated hex like '#2F5D50' (or absent)
}

export interface PublishedMenu {
  id: string;
  slug: string;
  name: string;
  currency: string;
  sourceLocale: Locale;
  availableLocales: Locale[];
  timeSlot: TimeSlot;
  timeSlotDescription: string | null;
  coverImageUrl: string | null;
  publishedAt: string;
  templateId: TemplateId;
  themeOverrides: ThemeOverrides;
  store: Store;
  categories: Category[];
}

export interface Store {
  id: string;
  logoUrl: string | null;
  sourceName: string;
  sourceAddress: string | null;
  translations: Record<Locale, { name: string; address: string | null }>;
  customBrandingOff: boolean;
  tier: 'free' | 'pro' | 'growth';
  qrViewsMonthlyCount: number;
}

export interface Category {
  id: string;
  sourceName: string;
  position: number;
  translations: Record<Locale, { name: string }>;
  dishes: Dish[];
}

export interface Dish {
  id: string;
  sourceName: string;
  sourceDescription: string | null;
  price: number;
  imageUrl: string | null;
  position: number;
  spiceLevel: SpiceLevel;
  isSignature: boolean;
  isRecommended: boolean;
  isVegetarian: boolean;
  soldOut: boolean;
  allergens: string[];
  translations: Record<Locale, { name: string; description: string | null }>;
}

/** Helper: resolve the user-visible name/description for a given locale,
 *  falling back to the source fields. */
export function dishName(d: Dish, locale: Locale): string {
  return d.translations[locale]?.name ?? d.sourceName;
}
export function dishDescription(d: Dish, locale: Locale): string | null {
  return d.translations[locale]?.description ?? d.sourceDescription;
}
export function categoryName(c: Category, locale: Locale): string {
  return c.translations[locale]?.name ?? c.sourceName;
}
export function storeName(s: Store, locale: Locale): string {
  return s.translations[locale]?.name ?? s.sourceName;
}
export function storeAddress(s: Store, locale: Locale): string | null {
  return s.translations[locale]?.address ?? s.sourceAddress;
}
