<script lang="ts">
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import MinimalDishCard from './MinimalDishCard.svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { categoryName } from '$lib/types/menu';
  import { applyFilters, type FilterState } from '$lib/search/applyFilters';

  let { data }: { data: { menu: import('$lib/types/menu').PublishedMenu; lang: string } } = $props();
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

  $effect(() => {
    if (typeof localStorage === 'undefined') return;
    const stored = localStorage.getItem('menuray.lang');
    const urlLang = page.url.searchParams.get('lang');
    if (!urlLang && stored && menu.availableLocales.includes(stored) && stored !== data.lang) {
      const url = new URL(page.url);
      url.searchParams.set('lang', stored);
      goto(url.pathname + '?' + url.searchParams.toString(), { noScroll: true, replaceState: true });
    }
  });

  $effect(() => {
    if (typeof document !== 'undefined') document.documentElement.lang = locale;
  });
</script>

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
          <MinimalDishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" menuId={menu.id} storeDishTrackingEnabled={menu.store.dishTrackingEnabled} />
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
