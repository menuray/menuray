import type { Locale } from '$lib/types/menu';

type StringKey =
  | 'search.placeholder'
  | 'filter.label'
  | 'filter.spice'
  | 'filter.vegetarian'
  | 'filter.signature'
  | 'filter.recommended'
  | 'filter.clear'
  | 'badge.poweredBy'
  | 'back'
  | 'soldOut'
  | 'dish.signature'
  | 'dish.recommended'
  | 'dish.vegetarian'
  | 'spice.mild'
  | 'spice.medium'
  | 'spice.hot'
  | 'error.notFound.title'
  | 'error.notFound.body'
  | 'error.gone.title'
  | 'error.gone.body';

const en: Record<StringKey, string> = {
  'search.placeholder': 'Search dishes',
  'filter.label': 'Filter',
  'filter.spice': 'Spice',
  'filter.vegetarian': 'Vegetarian',
  'filter.signature': 'Signature',
  'filter.recommended': 'Recommended',
  'filter.clear': 'Clear',
  'badge.poweredBy': 'Powered by MenuRay \u2192',
  'back': 'Back',
  'soldOut': 'Sold out',
  'dish.signature': 'Signature',
  'dish.recommended': 'Recommended',
  'dish.vegetarian': 'Vegetarian',
  'spice.mild': 'Mild',
  'spice.medium': 'Medium',
  'spice.hot': 'Hot',
  'error.notFound.title': 'Menu not found',
  'error.notFound.body': 'The menu you\u2019re looking for doesn\u2019t exist.',
  'error.gone.title': 'Menu unavailable',
  'error.gone.body': 'This menu is no longer available.',
};

const zh: Record<StringKey, string> = {
  'search.placeholder': '搜索菜品',
  'filter.label': '筛选',
  'filter.spice': '辣度',
  'filter.vegetarian': '素食',
  'filter.signature': '招牌',
  'filter.recommended': '推荐',
  'filter.clear': '清除',
  'badge.poweredBy': '由 MenuRay 提供 \u2192',
  'back': '返回',
  'soldOut': '已售罄',
  'dish.signature': '招牌',
  'dish.recommended': '推荐',
  'dish.vegetarian': '素食',
  'spice.mild': '微辣',
  'spice.medium': '中辣',
  'spice.hot': '重辣',
  'error.notFound.title': '菜单不存在',
  'error.notFound.body': '您访问的菜单不存在。',
  'error.gone.title': '菜单不可用',
  'error.gone.body': '此菜单已不再提供。',
};

export function t(locale: Locale, key: StringKey): string {
  const table = locale.startsWith('zh') ? zh : en;
  return table[key];
}
