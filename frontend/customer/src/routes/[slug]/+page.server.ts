import type { PageServerLoad } from './$types';
import { error } from '@sveltejs/kit';
import { fetchPublishedMenu } from '$lib/data/fetchPublishedMenu';
import { logView } from '$lib/data/logView';
import { resolveLocale } from '$lib/i18n/resolveLocale';
import { buildMenuJsonLd } from '$lib/seo/jsonLd';

const FREE_QR_CAP = 2000;

export const load: PageServerLoad = async ({ locals, params, url, request }) => {
  const menu = await fetchPublishedMenu(locals.supabase, params.slug);
  if (!menu) throw error(404, 'Menu not found');

  if (menu.store.tier === 'free' && menu.store.qrViewsMonthlyCount >= FREE_QR_CAP) {
    throw error(402, 'qr_view_quota_exceeded');
  }

  const locale = resolveLocale({
    urlLang: url.searchParams.get('lang'),
    storedLang: null,
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
