<script lang="ts">
  import type { Dish, Locale } from '$lib/types/menu';
  import { dishName } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';
  import DishViewTracker from '$lib/components/DishViewTracker.svelte';

  let { dish, locale, currency, href, menuId, storeDishTrackingEnabled, qrVariant = null }:
    { dish: Dish; locale: Locale; currency: string; href: string; menuId: string; storeDishTrackingEnabled: boolean; qrVariant?: string | null } = $props();
  const name = $derived(dishName(dish, locale));
  const priceDisplay = $derived(formatPrice(dish.price, currency));

  function formatPrice(p: number, curr: string): string {
    try {
      return new Intl.NumberFormat(locale, { style: 'currency', currency: curr }).format(p);
    } catch {
      return `${curr} ${p.toFixed(2)}`;
    }
  }
</script>

<DishViewTracker {menuId} dishId={dish.id} enabled={storeDishTrackingEnabled} {qrVariant}>
<a
  {href}
  class="flex flex-col gap-1.5 rounded-2xl overflow-hidden transition-transform hover:-translate-y-0.5
         {dish.soldOut ? 'opacity-50' : ''}"
  aria-label={name}
>
  <div class="w-full aspect-square rounded-2xl overflow-hidden bg-[#E6E2DB]">
    {#if dish.imageUrl}
      <img src={dish.imageUrl} alt="" class="w-full h-full object-cover" />
    {:else}
      <div class="w-full h-full flex items-center justify-center text-secondary">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" aria-hidden="true">
          <path d="M3 13h18v2a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4v-2Zm2-2a7 7 0 0 1 14 0H5Z"
                stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
      </div>
    {/if}
  </div>
  <div class="px-0.5">
    <div class="flex items-baseline justify-between gap-1">
      <h3 class="text-sm font-medium text-ink line-clamp-2">{name}</h3>
    </div>
    <p class="text-sm font-semibold text-primary mt-0.5">{priceDisplay}</p>
    <div class="flex gap-1 mt-1 flex-nowrap overflow-hidden">
      {#if dish.isSignature}
        <span class="text-[10px] px-1 py-0.5 rounded bg-accent/20 text-accent font-medium whitespace-nowrap">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-[10px] px-1 py-0.5 rounded bg-primary/10 text-primary font-medium whitespace-nowrap">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-[10px] px-1 py-0.5 rounded bg-primary/10 text-primary whitespace-nowrap">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-[10px] px-1 py-0.5 rounded bg-error/10 text-error whitespace-nowrap">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>
  </div>
</a>
</DishViewTracker>
