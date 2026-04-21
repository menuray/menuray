<script lang="ts">
  import type { Dish, Locale } from '$lib/types/menu';
  import { dishName, dishDescription } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { dish, locale, currency, href }:
    { dish: Dish; locale: Locale; currency: string; href: string } = $props();
  const name = $derived(dishName(dish, locale));
  const desc = $derived(dishDescription(dish, locale));
  const priceDisplay = $derived(formatPrice(dish.price, currency));

  function formatPrice(p: number, curr: string): string {
    try {
      return new Intl.NumberFormat(locale, { style: 'currency', currency: curr }).format(p);
    } catch {
      return `${curr} ${p.toFixed(2)}`;
    }
  }
</script>

<a
  {href}
  class="flex gap-4 p-4 rounded-2xl hover:bg-divider/30 transition-colors
         {dish.soldOut ? 'opacity-50' : ''}"
  aria-label={name}
>
  {#if dish.imageUrl}
    <img src={dish.imageUrl} alt="" class="w-16 h-16 rounded-xl object-cover bg-divider shrink-0" />
  {/if}
  <div class="flex-1 min-w-0">
    <div class="flex items-start justify-between gap-2">
      <h3 class="font-medium text-ink truncate">{name}</h3>
      <span class="font-semibold text-primary whitespace-nowrap">{priceDisplay}</span>
    </div>
    {#if desc}
      <p class="text-sm text-secondary line-clamp-2 mt-1">{desc}</p>
    {/if}
    <div class="flex flex-wrap gap-1 mt-2">
      {#if dish.isSignature}
        <span class="text-xs px-1.5 py-0.5 rounded bg-accent/20 text-accent font-medium">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-xs px-1.5 py-0.5 rounded bg-primary/10 text-primary font-medium">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-xs px-1.5 py-0.5 rounded bg-primary/10 text-primary">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-xs px-1.5 py-0.5 rounded bg-error/10 text-error">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>
  </div>
</a>
