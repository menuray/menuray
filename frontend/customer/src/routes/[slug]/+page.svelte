<script lang="ts">
  import type { PageData } from './$types';
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import DishCard from '$lib/components/DishCard.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import { categoryName, storeName } from '$lib/types/menu';
  import { applyFilters, type FilterState } from '$lib/search/applyFilters';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  let filters = $state<FilterState>({
    query: '',
    spice: new Set(),
    vegetarian: false,
    signature: false,
    recommended: false,
  });
  let filterOpen = $state(false);
  let activeCategoryId = $state<string | null>(null);

  const visibleCategories = $derived(applyFilters(menu.categories, filters, locale));
  const activeFilterCount = $derived(
    (filters.spice.size > 0 ? 1 : 0)
    + (filters.vegetarian ? 1 : 0)
    + (filters.signature ? 1 : 0)
    + (filters.recommended ? 1 : 0),
  );

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

<SearchBar
  bind:value={filters.query}
  {locale}
  onFilterClick={() => (filterOpen = true)}
  {activeFilterCount}
/>

<CategoryNav
  categories={visibleCategories}
  {locale}
  activeId={activeCategoryId}
  onSelect={scrollToCategory}
/>

<main class="max-w-3xl mx-auto px-2 py-4">
  {#each visibleCategories as cat (cat.id)}
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

  {#if visibleCategories.length === 0}
    <div class="text-center py-16 text-secondary">
      <p>—</p>
    </div>
  {/if}
</main>

<FilterDrawer bind:open={filterOpen} bind:filters {locale} />
