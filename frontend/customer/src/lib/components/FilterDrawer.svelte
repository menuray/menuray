<script lang="ts">
  import type { Locale, SpiceLevel } from '$lib/types/menu';
  import type { FilterState } from '$lib/search/applyFilters';
  import { t } from '$lib/i18n/strings';

  let {
    open = $bindable(false),
    filters = $bindable(),
    locale,
  }: {
    open: boolean;
    filters: FilterState;
    locale: Locale;
  } = $props();

  const SPICE_LEVELS: Exclude<SpiceLevel, 'none'>[] = ['mild', 'medium', 'hot'];

  function toggleSpice(s: SpiceLevel) {
    const next = new Set(filters.spice);
    if (next.has(s)) next.delete(s); else next.add(s);
    filters = { ...filters, spice: next };
  }

  function clearAll() {
    filters = { query: filters.query, spice: new Set(), vegetarian: false, signature: false, recommended: false };
  }
</script>

{#if open}
  <div
    class="fixed inset-0 z-40 bg-ink/40"
    onclick={() => (open = false)}
    onkeydown={(e) => e.key === 'Escape' && (open = false)}
    role="button"
    tabindex="-1"
    aria-label="Close filter"
  ></div>
  <div
    class="fixed z-50 inset-x-0 bottom-0 md:inset-y-0 md:right-0 md:left-auto md:w-80
           bg-surface shadow-xl rounded-t-2xl md:rounded-t-none md:rounded-l-2xl
           p-4 pb-10 md:pb-4 max-h-[80vh] overflow-y-auto"
    role="dialog"
    aria-modal="true"
  >
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold">{t(locale, 'filter.label')}</h2>
      <button type="button" onclick={clearAll} class="text-sm text-primary">
        {t(locale, 'filter.clear')}
      </button>
    </div>

    <section class="mb-4">
      <p class="text-sm font-medium text-ink mb-2">{t(locale, 'filter.spice')}</p>
      <div class="flex flex-wrap gap-2">
        {#each SPICE_LEVELS as level (level)}
          <button
            type="button"
            onclick={() => toggleSpice(level)}
            class="px-3 py-1.5 rounded-full text-sm border transition-colors
                   {filters.spice.has(level)
                     ? 'bg-primary text-surface border-primary'
                     : 'border-divider text-ink hover:border-primary'}"
          >
            {t(locale, `spice.${level}`)}
          </button>
        {/each}
      </div>
    </section>

    <section class="flex flex-col gap-3">
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.vegetarian} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.vegetarian')}
      </label>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.signature} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.signature')}
      </label>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={filters.recommended} class="w-4 h-4 accent-primary" />
        {t(locale, 'filter.recommended')}
      </label>
    </section>
  </div>
{/if}
