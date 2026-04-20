import { describe, it, expect } from 'vitest';
import { applyFilters, type FilterState } from './applyFilters';
import type { Category, Dish } from '$lib/types/menu';

const dish = (overrides: Partial<Dish> = {}): Dish => ({
  id: 'd' + Math.random(),
  sourceName: 'Kung Pao Chicken',
  sourceDescription: 'Spicy peanut stir-fry',
  price: 58,
  imageUrl: null,
  position: 0,
  spiceLevel: 'medium',
  isSignature: false,
  isRecommended: false,
  isVegetarian: false,
  soldOut: false,
  allergens: [],
  translations: {},
  ...overrides,
});

const cat = (dishes: Dish[]): Category => ({
  id: 'c1', sourceName: 'Mains', position: 0, translations: {}, dishes,
});

const emptyFilters: FilterState = {
  query: '',
  spice: new Set(),
  vegetarian: false,
  signature: false,
  recommended: false,
};

describe('applyFilters', () => {
  it('returns all categories unchanged when no filters apply', () => {
    const cats = [cat([dish(), dish({ sourceName: 'Other' })])];
    expect(applyFilters(cats, emptyFilters, 'en')).toEqual(cats);
  });

  it('filters by case-insensitive search in current locale', () => {
    const cats = [cat([dish({ sourceName: 'Kung Pao Chicken' }), dish({ sourceName: 'Ma Po Tofu' })])];
    const result = applyFilters(cats, { ...emptyFilters, query: 'kung' }, 'en');
    expect(result[0].dishes).toHaveLength(1);
    expect(result[0].dishes[0].sourceName).toBe('Kung Pao Chicken');
  });

  it('searches translated name when available', () => {
    const d = dish({
      sourceName: 'Kung Pao Chicken',
      translations: { 'zh-CN': { name: '宫保鸡丁', description: null } },
    });
    const cats = [cat([d])];
    expect(applyFilters(cats, { ...emptyFilters, query: '宫保' }, 'zh-CN')[0].dishes).toHaveLength(1);
    expect(applyFilters(cats, { ...emptyFilters, query: '宫保' }, 'en')).toHaveLength(0);
  });

  it('filters by vegetarian', () => {
    const cats = [cat([dish({ isVegetarian: false }), dish({ isVegetarian: true })])];
    const result = applyFilters(cats, { ...emptyFilters, vegetarian: true }, 'en');
    expect(result[0].dishes).toHaveLength(1);
  });

  it('filters by spice levels (set membership)', () => {
    const cats = [cat([
      dish({ spiceLevel: 'mild' }),
      dish({ spiceLevel: 'hot' }),
      dish({ spiceLevel: 'none' }),
    ])];
    const result = applyFilters(cats, { ...emptyFilters, spice: new Set(['mild', 'hot']) }, 'en');
    expect(result[0].dishes.map(d => d.spiceLevel).sort()).toEqual(['hot', 'mild']);
  });

  it('hides categories with no matching dishes', () => {
    const cats = [
      cat([dish({ isVegetarian: true })]),
      cat([dish({ isVegetarian: false })]),
    ];
    const result = applyFilters(cats, { ...emptyFilters, vegetarian: true }, 'en');
    expect(result).toHaveLength(1);
  });

  it('is diacritic-insensitive', () => {
    const d = dish({ sourceName: 'Café Crème' });
    const cats = [cat([d])];
    expect(applyFilters(cats, { ...emptyFilters, query: 'cafe creme' }, 'en')[0].dishes).toHaveLength(1);
  });
});
