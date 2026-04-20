<script lang="ts">
  import type { Category, Locale } from '$lib/types/menu';
  import { categoryName } from '$lib/types/menu';

  let { categories, locale, activeId, onSelect }:
    { categories: Category[]; locale: Locale; activeId: string | null; onSelect: (id: string) => void } =
    $props();
</script>

<nav class="sticky top-0 z-30 bg-surface/95 backdrop-blur border-b border-divider">
  <div class="max-w-3xl mx-auto flex gap-2 overflow-x-auto px-4 py-2 no-scrollbar">
    {#each categories as cat (cat.id)}
      <button
        type="button"
        class="shrink-0 px-3 py-1.5 rounded-full text-sm transition-colors
               {activeId === cat.id
                 ? 'bg-primary text-surface'
                 : 'bg-divider/50 text-ink hover:bg-divider'}"
        onclick={() => onSelect(cat.id)}
      >
        {categoryName(cat, locale)}
      </button>
    {/each}
  </div>
</nav>

<style>
  .no-scrollbar { scrollbar-width: none; }
  .no-scrollbar::-webkit-scrollbar { display: none; }
</style>
