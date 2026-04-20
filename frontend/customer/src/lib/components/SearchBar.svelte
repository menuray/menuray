<script lang="ts">
  import type { Locale } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let {
    value = $bindable(''),
    locale,
    onFilterClick,
    activeFilterCount,
  }: {
    value: string;
    locale: Locale;
    onFilterClick: () => void;
    activeFilterCount: number;
  } = $props();
</script>

<div class="flex gap-2 px-4 py-2 bg-surface border-b border-divider">
  <input
    type="search"
    bind:value
    placeholder={t(locale, 'search.placeholder')}
    class="flex-1 h-10 px-3 rounded-button border border-divider bg-surface
           text-ink placeholder:text-secondary focus:outline-none focus:border-primary"
  />
  <button
    type="button"
    onclick={onFilterClick}
    class="relative h-10 px-3 rounded-button border border-divider text-ink
           hover:border-primary transition-colors flex items-center gap-1"
  >
    {t(locale, 'filter.label')}
    {#if activeFilterCount > 0}
      <span class="ml-1 inline-flex items-center justify-center min-w-5 h-5 px-1
                   rounded-full bg-primary text-surface text-xs font-medium">
        {activeFilterCount}
      </span>
    {/if}
  </button>
</div>
