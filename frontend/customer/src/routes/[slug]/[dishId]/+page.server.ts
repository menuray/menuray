import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { resolveLocale } from '$lib/i18n/resolveLocale';

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  let foundDish = null;
  let foundCategory = null;
  for (const cat of menu.categories) {
    const d = cat.dishes.find((x) => x.id === params.dishId);
    if (d) {
      foundDish = d;
      foundCategory = cat;
      break;
    }
  }
  if (!foundDish || !foundCategory) throw error(404, 'Dish not found');

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,
    acceptLanguage: request.headers.get('accept-language'),
    available: menu.availableLocales,
    source: menu.sourceLocale,
  });

  return {
    menu,
    category: foundCategory,
    dish: foundDish,
    lang: locale,
  };
};
