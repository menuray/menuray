import { test, expect } from '@playwright/test';
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'http://127.0.0.1:54321';
// Service role key from local Supabase default (no secrets — local only).
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
  ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

test('archived menu returns 404 page', async ({ page }) => {
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });

  try {
    // Flip the seeded menu to archived.
    const { error } = await admin.from('menus').update({ status: 'archived' }).eq('slug', SLUG);
    expect(error).toBeNull();

    const resp = await page.goto(`/${SLUG}`);
    expect(resp!.status()).toBe(404);
    // Error page rendered.
    await expect(page.getByText(/Menu not found/i)).toBeVisible();
  } finally {
    // Always flip back so subsequent tests still work.
    await admin.from('menus').update({ status: 'published' }).eq('slug', SLUG);
  }
});
