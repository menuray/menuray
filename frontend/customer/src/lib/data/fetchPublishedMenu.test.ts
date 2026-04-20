import { describe, it, expect } from 'vitest';
import { createSupabaseClient } from '$lib/supabase';
import { fetchPublishedMenu } from './fetchPublishedMenu';

describe('fetchPublishedMenu (integration)', () => {
  const supabase = createSupabaseClient();
  const SLUG = 'yun-jian-xiao-chu-lunch-2025';

  it('returns the full menu tree for a published slug', async () => {
    const menu = await fetchPublishedMenu(supabase, SLUG);
    expect(menu).not.toBeNull();
    expect(menu!.slug).toBe(SLUG);
    expect(menu!.name).toBeTruthy();
    expect(menu!.store.sourceName).toBeTruthy();
    expect(menu!.categories.length).toBeGreaterThan(0);
    expect(menu!.categories[0].dishes.length).toBeGreaterThan(0);
    // Sorted by position ascending
    const positions = menu!.categories.map(c => c.position);
    expect([...positions].sort((a, b) => a - b)).toEqual(positions);
  });

  it('returns null for an unknown slug', async () => {
    const menu = await fetchPublishedMenu(supabase, 'no-such-slug-exists-here');
    expect(menu).toBeNull();
  });

  it('resolves translations into a keyed map', async () => {
    const menu = await fetchPublishedMenu(supabase, SLUG);
    expect(menu!.availableLocales).toContain(menu!.sourceLocale);
    // The seed inserts en translations for a couple of dishes.
    const hasAnyEnTranslation = menu!.categories.some(c =>
      c.dishes.some(d => d.translations['en']?.name !== undefined),
    );
    expect(hasAnyEnTranslation).toBe(true);
  });
});
