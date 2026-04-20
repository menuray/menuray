<script lang="ts">
  import type { PageData } from './$types';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import AllergensPills from '$lib/components/AllergensPills.svelte';
  import SpiceIndicator from '$lib/components/SpiceIndicator.svelte';
  import { dishName, dishDescription, categoryName, storeName } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const dish = $derived(data.dish);
  const category = $derived(data.category);
  const locale = $derived(data.lang);

  const name = $derived(dishName(dish, locale));
  const desc = $derived(dishDescription(dish, locale));
  const priceDisplay = $derived(
    (() => {
      try {
        return new Intl.NumberFormat(locale, { style: 'currency', currency: menu.currency }).format(dish.price);
      } catch {
        return `${menu.currency} ${dish.price.toFixed(2)}`;
      }
    })(),
  );

  $effect(() => {
    if (typeof document !== 'undefined') document.documentElement.lang = locale;
  });

  function back() {
    // Prefer history back if we arrived from B1; fall back to slug home.
    if (typeof history !== 'undefined' && history.length > 1 && document.referrer.includes(`/${menu.slug}`)) {
      history.back();
    } else {
      goto(`/${menu.slug}${page.url.search}`, { noScroll: false });
    }
  }

  const title = $derived(`${name} — ${storeName(menu.store, locale)} | MenuRay`);
</script>

<svelte:head>
  <title>{title}</title>
  {#if desc}<meta name="description" content={desc.slice(0, 155)} />{/if}
  {#if dish.imageUrl}<meta property="og:image" content={dish.imageUrl} />{/if}
  <meta property="og:title" content={title} />
  <meta property="og:locale" content={locale} />
</svelte:head>

<div class="min-h-dvh bg-surface">
  <button
    type="button"
    onclick={back}
    class="sticky top-0 z-30 w-full px-4 py-3 text-sm text-primary bg-surface/95 backdrop-blur border-b border-divider text-left"
  >
    ← {t(locale, 'back')}
  </button>

  {#if dish.imageUrl}
    <img src={dish.imageUrl} alt="" class="w-full max-w-3xl mx-auto aspect-video object-cover bg-divider" />
  {/if}

  <article class="max-w-3xl mx-auto px-4 py-6 flex flex-col gap-4">
    <div class="flex items-start justify-between gap-3">
      <div class="flex-1 min-w-0">
        <p class="text-sm text-secondary">{categoryName(category, locale)}</p>
        <h1 class="text-2xl font-semibold text-ink mt-0.5">{name}</h1>
      </div>
      <span class="text-xl font-semibold text-primary whitespace-nowrap">{priceDisplay}</span>
    </div>

    {#if desc}
      <p class="text-ink leading-relaxed">{desc}</p>
    {/if}

    <div class="flex flex-wrap gap-2 items-center">
      {#if dish.isSignature}
        <span class="text-xs px-2 py-0.5 rounded-full bg-accent/20 text-accent font-medium">
          {t(locale, 'dish.signature')}
        </span>
      {/if}
      {#if dish.isRecommended}
        <span class="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary font-medium">
          {t(locale, 'dish.recommended')}
        </span>
      {/if}
      {#if dish.isVegetarian}
        <span class="text-xs px-2 py-0.5 rounded-full bg-primary/10 text-primary">
          {t(locale, 'dish.vegetarian')}
        </span>
      {/if}
      {#if dish.soldOut}
        <span class="text-xs px-2 py-0.5 rounded-full bg-error/10 text-error">
          {t(locale, 'soldOut')}
        </span>
      {/if}
    </div>

    <SpiceIndicator level={dish.spiceLevel} {locale} />
    <AllergensPills allergens={dish.allergens} />
  </article>
</div>
