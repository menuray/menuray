import type { PublishedMenu, Locale } from '$lib/types/menu';
import {
  dishName, dishDescription, categoryName, storeName, storeAddress,
} from '$lib/types/menu';

export interface MenuJsonLd {
  '@context': 'https://schema.org';
  '@type': 'Restaurant';
  name: string;
  address?: string;
  image?: string;
  hasMenu: {
    '@type': 'Menu';
    name: string;
    hasMenuSection: Array<{
      '@type': 'MenuSection';
      name: string;
      hasMenuItem: Array<{
        '@type': 'MenuItem';
        name: string;
        description?: string;
        image?: string;
        offers: {
          '@type': 'Offer';
          price: string;
          priceCurrency: string;
        };
      }>;
    }>;
  };
}

export function buildMenuJsonLd(menu: PublishedMenu, locale: Locale): MenuJsonLd {
  const address = storeAddress(menu.store, locale);
  return {
    '@context': 'https://schema.org',
    '@type': 'Restaurant',
    name: storeName(menu.store, locale),
    ...(address ? { address } : {}),
    ...(menu.coverImageUrl ? { image: menu.coverImageUrl } : {}),
    hasMenu: {
      '@type': 'Menu',
      name: menu.name,
      hasMenuSection: menu.categories.map((cat) => ({
        '@type': 'MenuSection',
        name: categoryName(cat, locale),
        hasMenuItem: cat.dishes.map((d) => {
          const desc = dishDescription(d, locale);
          return {
            '@type': 'MenuItem',
            name: dishName(d, locale),
            ...(desc ? { description: desc } : {}),
            ...(d.imageUrl ? { image: d.imageUrl } : {}),
            offers: {
              '@type': 'Offer',
              price: String(d.price),
              priceCurrency: menu.currency,
            },
          };
        }),
      })),
    },
  };
}
