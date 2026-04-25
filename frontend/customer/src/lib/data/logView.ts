import type { SupabaseClient } from '@supabase/supabase-js';

export async function logView(
  supabase: SupabaseClient,
  menuId: string,
  storeId: string,
  locale: string,
  requestHeaders: Headers,
  requestUrl: URL,
  qrVariant: string | null,
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
    // Server-side cannot read the diner's sessionStorage; we generate a
    // request-scoped UUID instead. Two consecutive visits from the same tab
    // will therefore count as two sessions — acceptable MVP approximation.
    const requestSessionId = crypto.randomUUID();
    await supabase.from('view_logs').insert({
      menu_id: menuId,
      store_id: storeId,
      locale,
      session_id: requestSessionId,
      referrer_domain: referrerDomain,
      qr_variant: qrVariant,
    });
  } catch (e) {
    console.warn('logView failed (non-fatal)', e);
  }
}
