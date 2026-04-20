<script lang="ts">
  import type { PageData } from './$types';
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import DishCard from '$lib/components/DishCard.svelte';
  import { categoryName, storeName } from '$lib/types/menu';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  let activeCategoryId = $state<string | null>(null);

  function scrollToCategory(id: string) {
    activeCategoryId = id;
    document.getElementById(`category-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  const title = $derived(`${storeName(menu.store, locale)} — ${menu.name} | MenuRay`);
  const description = $derived(
    `${menu.categories.length} categories, ${menu.categories.reduce((n, c) => n + c.dishes.length, 0)} dishes`,
  );
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />
  {#if menu.coverImageUrl}
    <meta property="og:image" content={menu.coverImageUrl} />
  {/if}
  <meta property="og:title" content={title} />
  <meta property="og:locale" content={locale} />
  {@html `<script type="application/ld+json">${JSON.stringify(data.jsonLd)}</` + `script>`}
</svelte:head>

<MenuHeader {menu} {locale} />
<CategoryNav
  categories={menu.categories}
  {locale}
  activeId={activeCategoryId}
  onSelect={scrollToCategory}
/>

<main class="max-w-3xl mx-auto px-2 py-4">
  {#each menu.categories as cat (cat.id)}
    <section id="category-{cat.id}" class="mb-8">
      <h2 class="px-2 mb-2 text-lg font-semibold text-ink">
        {categoryName(cat, locale)}
      </h2>
      <div class="flex flex-col gap-1">
        {#each cat.dishes as dish (dish.id)}
          <DishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" />
        {/each}
      </div>
    </section>
  {/each}
</main>
