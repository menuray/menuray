<script lang="ts">
  import MenuHeader from '$lib/components/MenuHeader.svelte';
  import CategoryNav from '$lib/components/CategoryNav.svelte';
  import SearchBar from '$lib/components/SearchBar.svelte';
  import FilterDrawer from '$lib/components/FilterDrawer.svelte';
  import CoverHero from './CoverHero.svelte';
  import GridDishCard from './GridDishCard.svelte';
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

<CoverHero {menu} {locale} />
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

<main class="max-w-5xl mx-auto px-3 py-4">
  {#each visibleCategories as cat (cat.id)}
    <section id="category-{cat.id}" class="mb-10">
      <h2 class="px-1 mb-3 text-xl font-semibold text-ink">
        {categoryName(cat, locale)}
      </h2>
      <div class="grid grid-cols-2 md:grid-cols-3 gap-3">
        {#each cat.dishes as dish (dish.id)}
          <GridDishCard {dish} {locale} currency={menu.currency} href="/{menu.slug}/{dish.id}" menuId={menu.id} storeDishTrackingEnabled={menu.store.dishTrackingEnabled} />
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
