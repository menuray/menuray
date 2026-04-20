import type { Category, Dish, Locale, SpiceLevel } from '$lib/types/menu';
import { dishName, dishDescription } from '$lib/types/menu';

export interface FilterState {
  query: string;
  spice: Set<SpiceLevel>;
  vegetarian: boolean;
  signature: boolean;
  recommended: boolean;
}

function normalize(s: string): string {
  return s.normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}

function dishMatches(dish: Dish, f: FilterState, locale: Locale): boolean {
  if (f.vegetarian && !dish.isVegetarian) return false;
  if (f.signature && !dish.isSignature) return false;
  if (f.recommended && !dish.isRecommended) return false;
  if (f.spice.size > 0 && !f.spice.has(dish.spiceLevel)) return false;

  if (f.query.trim() === '') return true;
  const q = normalize(f.query);
  const name = normalize(dishName(dish, locale));
  const desc = normalize(dishDescription(dish, locale) ?? '');
  return name.includes(q) || desc.includes(q);
}

export function applyFilters(
  categories: Category[],
  filters: FilterState,
  locale: Locale,
): Category[] {
  return categories
    .map((c) => ({ ...c, dishes: c.dishes.filter((d) => dishMatches(d, filters, locale)) }))
    .filter((c) => c.dishes.length > 0);
}
