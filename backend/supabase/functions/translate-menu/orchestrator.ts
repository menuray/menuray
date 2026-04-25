import type { SupabaseClient } from "@supabase/supabase-js";
import type { TranslateProvider } from "../_shared/providers/types.ts";
import { getTranslateProvider } from "../_shared/providers/factory.ts";
import { createServiceRoleClient } from "../_shared/db.ts";

type TranslateResult = {
  translatedDishCount: number;
  translatedCategoryCount: number;
  availableLocales: string[];
};

type MenuRow = {
  id: string;
  store_id: string;
  source_locale: string;
  available_locales: string[];
};

type CategoryRow = { id: string; source_name: string };
type DishRow = {
  id: string;
  category_id: string | null;
  source_name: string;
  source_description: string | null;
};

export async function runTranslate(
  menuId: string,
  targetLocale: string,
  opts: { db?: SupabaseClient; provider?: TranslateProvider } = {},
): Promise<TranslateResult> {
  const db = opts.db ?? createServiceRoleClient();
  const provider = opts.provider ?? getTranslateProvider();

  const { data: menuRow, error: menuErr } = await db
    .from("menus")
    .select("id, store_id, source_locale, available_locales")
    .eq("id", menuId)
    .single();
  if (menuErr || !menuRow) {
    throw new Error(`menu lookup failed: ${menuErr?.message ?? "not found"}`);
  }
  const menu = menuRow as MenuRow;

  if (targetLocale === menu.source_locale) {
    throw new Error("target_locale_equals_source");
  }

  const { data: categories, error: catErr } = await db
    .from("categories")
    .select("id, source_name")
    .eq("menu_id", menuId)
    .order("position");
  if (catErr) throw new Error(`categories.select failed: ${catErr.message}`);

  const { data: dishes, error: dishErr } = await db
    .from("dishes")
    .select("id, category_id, source_name, source_description")
    .eq("menu_id", menuId);
  if (dishErr) throw new Error(`dishes.select failed: ${dishErr.message}`);

  const cats = (categories ?? []) as CategoryRow[];
  const dishList = (dishes ?? []) as DishRow[];

  const out = await provider.translate(
    {
      sourceLocale: menu.source_locale,
      categories: cats.map((c) => ({ id: c.id, sourceName: c.source_name })),
      dishes: dishList.map((d) => ({
        id: d.id,
        sourceName: d.source_name,
        sourceDescription: d.source_description,
      })),
    },
    targetLocale,
  );

  // Upsert category translations.
  if (out.categories.length > 0) {
    const rows = out.categories.map((c) => ({
      category_id: c.id,
      store_id: menu.store_id,
      locale: targetLocale,
      name: c.name,
    }));
    const { error } = await db
      .from("category_translations")
      .upsert(rows, { onConflict: "category_id,locale" });
    if (error) throw new Error(`category_translations.upsert: ${error.message}`);
  }

  // Upsert dish translations.
  if (out.dishes.length > 0) {
    const rows = out.dishes.map((d) => ({
      dish_id: d.id,
      store_id: menu.store_id,
      locale: targetLocale,
      name: d.name,
      description: d.description.length > 0 ? d.description : null,
    }));
    const { error } = await db
      .from("dish_translations")
      .upsert(rows, { onConflict: "dish_id,locale" });
    if (error) throw new Error(`dish_translations.upsert: ${error.message}`);
  }

  // Bump menus.available_locales if missing.
  const existingLocales = menu.available_locales ?? [];
  let availableLocales = existingLocales;
  if (!existingLocales.includes(targetLocale)) {
    availableLocales = [...existingLocales, targetLocale];
    const { error } = await db
      .from("menus")
      .update({ available_locales: availableLocales })
      .eq("id", menuId);
    if (error) throw new Error(`menus.update available_locales: ${error.message}`);
  }

  return {
    translatedDishCount: out.dishes.length,
    translatedCategoryCount: out.categories.length,
    availableLocales,
  };
}
