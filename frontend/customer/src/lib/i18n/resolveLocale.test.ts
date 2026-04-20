import { describe, it, expect } from 'vitest';
import { resolveLocale } from './resolveLocale';

describe('resolveLocale', () => {
  const available = ['en', 'zh-CN', 'ja'];
  const source = 'zh-CN';

  it('prefers the URL param when available', () => {
    expect(
      resolveLocale({ urlLang: 'ja', storedLang: 'en', acceptLanguage: 'fr', available, source }),
    ).toBe('ja');
  });

  it('ignores unsupported URL param and falls through', () => {
    expect(
      resolveLocale({ urlLang: 'fr', storedLang: 'en', acceptLanguage: null, available, source }),
    ).toBe('en');
  });

  it('uses storedLang when URL param is absent', () => {
    expect(
      resolveLocale({ urlLang: null, storedLang: 'ja', acceptLanguage: 'en', available, source }),
    ).toBe('ja');
  });

  it('parses Accept-Language with quality values', () => {
    expect(
      resolveLocale({
        urlLang: null, storedLang: null,
        acceptLanguage: 'fr;q=0.9,ja;q=0.8,en;q=0.7',
        available, source,
      }),
    ).toBe('ja');
  });

  it('falls back to source when nothing matches', () => {
    expect(
      resolveLocale({ urlLang: null, storedLang: null, acceptLanguage: 'fr', available, source }),
    ).toBe('zh-CN');
  });

  it('matches language-only against language-region (en → en-US not required here, exact match expected)', () => {
    expect(
      resolveLocale({ urlLang: 'en', storedLang: null, acceptLanguage: null,
                     available: ['en', 'zh-CN'], source: 'en' }),
    ).toBe('en');
  });
});
