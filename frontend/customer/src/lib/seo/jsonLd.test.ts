import { describe, it, expect } from 'vitest';
import { buildMenuJsonLd } from './jsonLd';
import type { PublishedMenu } from '$lib/types/menu';

const menu: PublishedMenu = {
  id: 'm1',
  slug: 'demo',
  name: 'Lunch Menu',
  currency: 'CNY',
  sourceLocale: 'zh-CN',
  availableLocales: ['zh-CN', 'en'],
  timeSlot: 'lunch',
  timeSlotDescription: null,
  coverImageUrl: 'https://example.com/cover.jpg',
  publishedAt: '2026-04-20T00:00:00Z',
  store: {
    id: 's1', logoUrl: null, sourceName: '云涧小厨', sourceAddress: null,
    translations: { en: { name: 'Yunjian Kitchen', address: null } },
    customBrandingOff: false,
  },
  categories: [{
    id: 'c1', sourceName: '凉菜', position: 0,
    translations: { en: { name: 'Cold' } },
    dishes: [{
      id: 'd1', sourceName: '宫保鸡丁', sourceDescription: '花生辣味',
      price: 58, imageUrl: null, position: 0, spiceLevel: 'medium',
      isSignature: false, isRecommended: false, isVegetarian: false,
      soldOut: false, allergens: [],
      translations: { en: { name: 'Kung Pao Chicken', description: 'Peanut spicy' } },
    }],
  }],
};

describe('buildMenuJsonLd', () => {
  it('produces a Restaurant with nested Menu + MenuSection + MenuItem', () => {
    const ld = buildMenuJsonLd(menu, 'en');
    expect(ld['@context']).toBe('https://schema.org');
    expect(ld['@type']).toBe('Restaurant');
    expect(ld.name).toBe('Yunjian Kitchen');
    expect(ld.hasMenu['@type']).toBe('Menu');
    expect(ld.hasMenu.hasMenuSection[0]['@type']).toBe('MenuSection');
    expect(ld.hasMenu.hasMenuSection[0].name).toBe('Cold');
    const item = ld.hasMenu.hasMenuSection[0].hasMenuItem[0];
    expect(item['@type']).toBe('MenuItem');
    expect(item.name).toBe('Kung Pao Chicken');
    expect(item.offers.price).toBe('58');
    expect(item.offers.priceCurrency).toBe('CNY');
  });

  it('falls back to source name when translation missing', () => {
    const ld = buildMenuJsonLd(menu, 'ja');
    expect(ld.name).toBe('云涧小厨');
    expect(ld.hasMenu.hasMenuSection[0].name).toBe('凉菜');
  });
});
