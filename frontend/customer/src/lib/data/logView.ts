import type { SupabaseClient } from '@supabase/supabase-js';

export async function logView(
  supabase: SupabaseClient,
  menuId: string,
  storeId: string,
  locale: string,
  requestHeaders: Headers,
  requestUrl: URL,
): Promise<void> {
  try {
    const referer = requestHeaders.get('referer');
    let referrerDomain: string | null = null;
    if (referer) {
      try {
        const refererHost = new URL(referer).hostname;
        if (refererHost !== requestUrl.hostname) referrerDomain = refererHost;
      } catch {
        /* malformed referer — drop */
      }
    }
    await supabase.from('view_logs').insert({
      menu_id: menuId,
      store_id: storeId,
      locale,
      session_id: null,
      referrer_domain: referrerDomain,
    });
  } catch (e) {
    console.warn('logView failed (non-fatal)', e);
  }
}
