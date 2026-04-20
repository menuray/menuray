import type { Locale } from '$lib/types/menu';

export interface ResolveLocaleInput {
  urlLang: string | null;
  storedLang: string | null;
  acceptLanguage: string | null;
  available: Locale[];
  source: Locale;
}

/** Precedence: URL param → localStorage → Accept-Language → source locale. */
export function resolveLocale(input: ResolveLocaleInput): Locale {
  const { urlLang, storedLang, acceptLanguage, available, source } = input;

  if (urlLang && available.includes(urlLang)) return urlLang;
  if (storedLang && available.includes(storedLang)) return storedLang;

  if (acceptLanguage) {
    const ranked = parseAcceptLanguage(acceptLanguage);
    for (const tag of ranked) {
      if (available.includes(tag)) return tag;
    }
  }

  return source;
}

function parseAcceptLanguage(header: string): string[] {
  return header
    .split(',')
    .map((piece) => {
      const [tag, ...params] = piece.trim().split(';');
      const qParam = params.find((p) => p.trim().startsWith('q='));
      const q = qParam ? parseFloat(qParam.split('=')[1]) : 1;
      return { tag: tag.trim(), q: isNaN(q) ? 0 : q };
    })
    .sort((a, b) => b.q - a.q)
    .map((r) => r.tag);
}
