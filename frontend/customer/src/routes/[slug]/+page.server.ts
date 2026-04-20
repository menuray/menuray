import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { logView } from '$lib/data/logView';
import { resolveLocale } from '$lib/i18n/resolveLocale';
import { buildMenuJsonLd } from '$lib/seo/jsonLd';

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,  // resolved client-side
    acceptLanguage: request.headers.get('accept-language'),
    available: menu.availableLocales,
    source: menu.sourceLocale,
  });

  logView(locals.supabase, menu.id, menu.store.id, locale, request.headers, url);

  return {
    menu,
    lang: locale,
    jsonLd: buildMenuJsonLd(menu, locale),
  };
};
