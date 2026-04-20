import { test, expect } from '@playwright/test';

const SLUG = 'yun-jian-xiao-chu-lunch-2025';

test('B1 renders the seeded menu and navigates to B2', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  // Menu title (in zh source locale).
  await expect(page.locator('h1').first()).toBeVisible();
  await expect(page.getByText('午市套餐 2025 春')).toBeVisible();

  // Category nav has at least one button.
  const catButtons = page.locator('nav button');
  await expect(catButtons.first()).toBeVisible();

  // Tap the first dish card.
  const firstDish = page.locator('main a[aria-label]').first();
  await firstDish.click();

  // Arrive on B2.
  await expect(page).toHaveURL(new RegExp(`/${SLUG}/[0-9a-f-]+`));
  await expect(page.getByText('返回')).toBeVisible();

  // Back button returns to B1.
  await page.getByText('返回').click();
  await expect(page).toHaveURL(new RegExp(`/${SLUG}(\\?.*)?$`));
});

test('search filters dishes in real time', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  const cardsBefore = await page.locator('main a[aria-label]').count();
  expect(cardsBefore).toBeGreaterThan(0);

  // Type a query that should match only the 宫保鸡丁-style dish.
  await page.getByPlaceholder('搜索菜品').fill('宫保');

  const cardsAfter = await page.locator('main a[aria-label]').count();
  expect(cardsAfter).toBeLessThan(cardsBefore);
});

test('language switcher flips visible UI strings', async ({ page }) => {
  await page.goto(`/${SLUG}`);

  // Default is zh (source_locale of seed).
  await expect(page.getByPlaceholder('搜索菜品')).toBeVisible();

  await page.getByRole('button', { name: /中文/ }).click();
  await page.getByRole('option', { name: 'English' }).click();

  await expect(page.getByPlaceholder('Search dishes')).toBeVisible();
  await expect(page).toHaveURL(/lang=en/);
});

test('JSON-LD script tag is emitted', async ({ page }) => {
  await page.goto(`/${SLUG}`);
  const json = await page.locator('script[type="application/ld+json"]').innerText();
  const parsed = JSON.parse(json);
  expect(parsed['@context']).toBe('https://schema.org');
  expect(parsed['@type']).toBe('Restaurant');
  expect(parsed.hasMenu['@type']).toBe('Menu');
});
