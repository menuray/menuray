import { test, expect } from '@playwright/test';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

function admin(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, { auth: { persistSession: false } });
}

async function resetMenu(client: SupabaseClient) {
  // Restore default state so subsequent tests (and manual dev) see Minimal + no overrides.
  await client.from('menus').update({ template_id: 'minimal', theme_overrides: {} }).eq('slug', SLUG);
}

test('grid template renders photo-card layout', async ({ page }) => {
  const a = admin();
  try {
    const { error } = await a.from('menus').update({ template_id: 'grid' }).eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // Grid layout puts dish cards inside a CSS grid. Assert the class is present.
    const gridSection = page.locator('main div[class*="grid-cols"]').first();
    await expect(gridSection).toBeVisible();

    // Page still shows the menu title.
    await expect(page.getByText('午市套餐 2025 春')).toBeVisible();
  } finally {
    await resetMenu(a);
  }
});

test('primary_color override injects CSS variable', async ({ page }) => {
  const a = admin();
  const OVERRIDE = '#C2553F';
  try {
    const { error } = await a
      .from('menus')
      .update({ theme_overrides: { primary_color: OVERRIDE } })
      .eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // The injected <style> sets :root{--color-primary:#...} — read it from computed styles.
    const value = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim(),
    );
    expect(value.toLowerCase()).toBe(OVERRIDE.toLowerCase());
  } finally {
    await resetMenu(a);
  }
});

test('invalid primary_color is silently ignored', async ({ page }) => {
  const a = admin();
  try {
    const { error } = await a
      .from('menus')
      .update({ theme_overrides: { primary_color: 'not-a-hex' } })
      .eq('slug', SLUG);
    expect(error).toBeNull();

    await page.goto(`/${SLUG}`);

    // Should fall back to the Tailwind @theme default.
    const value = await page.evaluate(() =>
      getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim(),
    );
    // Default is #2F5D50 (case-insensitive). Do not fail on whitespace / hex case.
    expect(value.toLowerCase()).toBe('#2f5d50');
  } finally {
    await resetMenu(a);
  }
});
