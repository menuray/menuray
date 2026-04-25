import type { SupabaseClient } from '@supabase/supabase-js';
import type {
  PublishedMenu, Store, Category, Dish, Locale, SpiceLevel, TimeSlot,
} from '$lib/types/menu';
import { isValidHex } from '$lib/templates/primarySwatches';

// Shape returned by the Supabase PostgREST join (minimal typing — not the
// full generated types, since we don't run the codegen yet).
type JoinedMenuRow = {
  id: string; slug: string; name: string; status: string; currency: string;
  source_locale: string; time_slot: TimeSlot; time_slot_description: string | null;
  cover_image_url: string | null; published_at: string;
  template_id: string;
  theme_overrides: { primary_color?: unknown } | null;
  store: {
    id: string; logo_url: string | null; name: string; address: string | null;
    source_locale: string;
    tier: 'free' | 'pro' | 'growth';
    qr_views_monthly_count: number;
    dish_tracking_enabled: boolean;
    store_translations: Array<{ locale: string; name: string; address: string | null }>;
  } | null;
  categories: Array<{
    id: string; source_name: string; position: number;
    category_translations: Array<{ locale: string; name: string }>;
    dishes: Array<{
      id: string; source_name: string; source_description: string | null;
      price: number | string; image_url: string | null; position: number;
      spice_level: SpiceLevel; is_signature: boolean; is_recommended: boolean;
      is_vegetarian: boolean; sold_out: boolean; allergens: string[];
      dish_translations: Array<{ locale: string; name: string; description: string | null }>;
    }>;
  }>;
};

export async function fetchPublishedMenu(
  supabase: SupabaseClient,
  slug: string,
): Promise<PublishedMenu | null> {
  const { data, error } = await supabase
    .from('menus')
    .select(`
      id, slug, name, status, currency, source_locale,
      time_slot, time_slot_description, cover_image_url, published_at, template_id, theme_overrides,
      store:stores (
        id, logo_url, name, address, source_locale, tier, qr_views_monthly_count, dish_tracking_enabled,
        store_translations ( locale, name, address )
      ),
      categories (
        id, source_name, position,
        category_translations ( locale, name ),
        dishes (
          id, source_name, source_description, price, image_url, position,
          spice_level, is_signature, is_recommended, is_vegetarian, sold_out, allergens,
          dish_translations ( locale, name, description )
        )
      )
    `)
    .eq('slug', slug)
    .eq('status', 'published')
    .maybeSingle<JoinedMenuRow>();

  if (error) {
    console.error('fetchPublishedMenu error', error);
    return null;
  }
  if (!data) return null;
  if (!data.store) return null;  // defensive: store RLS blocked → treat as 404

  return mapRow(data);
}

function mapRow(row: JoinedMenuRow): PublishedMenu {
  const store: Store = {
    id: row.store!.id,
    logoUrl: row.store!.logo_url,
    sourceName: row.store!.name,
    sourceAddress: row.store!.address,
    translations: Object.fromEntries(
      row.store!.store_translations.map((t) => [t.locale, { name: t.name, address: t.address }]),
    ),
    customBrandingOff: false,
    tier: row.store!.tier,
    qrViewsMonthlyCount: row.store!.qr_views_monthly_count,
    dishTrackingEnabled: row.store!.dish_tracking_enabled,
  };

  const categories: Category[] = [...row.categories]
    .sort((a, b) => a.position - b.position)
    .map<Category>((c) => ({
      id: c.id,
      sourceName: c.source_name,
      position: c.position,
      translations: Object.fromEntries(
        c.category_translations.map((t) => [t.locale, { name: t.name }]),
      ),
      dishes: [...c.dishes]
        .sort((a, b) => a.position - b.position)
        .map<Dish>((d) => ({
          id: d.id,
          sourceName: d.source_name,
          sourceDescription: d.source_description,
          price: typeof d.price === 'string' ? parseFloat(d.price) : d.price,
          imageUrl: d.image_url,
          position: d.position,
          spiceLevel: d.spice_level,
          isSignature: d.is_signature,
          isRecommended: d.is_recommended,
          isVegetarian: d.is_vegetarian,
          soldOut: d.sold_out,
          allergens: d.allergens,
          translations: Object.fromEntries(
            d.dish_translations.map((t) => [t.locale, { name: t.name, description: t.description }]),
          ),
        })),
    }));

  const allLocales = new Set<Locale>([row.source_locale]);
  for (const cat of categories) {
    Object.keys(cat.translations).forEach((l) => allLocales.add(l));
    for (const dish of cat.dishes) {
      Object.keys(dish.translations).forEach((l) => allLocales.add(l));
    }
  }
  Object.keys(store.translations).forEach((l) => allLocales.add(l));

  return {
    id: row.id,
    slug: row.slug,
    name: row.name,
    currency: row.currency,
    sourceLocale: row.source_locale,
    availableLocales: [...allLocales],
    timeSlot: row.time_slot,
    timeSlotDescription: row.time_slot_description,
    coverImageUrl: row.cover_image_url,
    publishedAt: row.published_at,
    templateId: (row.template_id ?? 'minimal') as PublishedMenu['templateId'],
    themeOverrides: mapThemeOverrides(row.theme_overrides),
    store,
    categories,
  };
}

function mapThemeOverrides(raw: { primary_color?: unknown } | null): PublishedMenu['themeOverrides'] {
  if (!raw || typeof raw !== 'object') return {};
  const pc = (raw as { primary_color?: unknown }).primary_color;
  if (isValidHex(pc)) return { primaryColor: pc };
  return {};
}
