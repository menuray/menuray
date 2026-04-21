<script lang="ts">
  import type { PublishedMenu, Locale } from '$lib/types/menu';
  import { storeName } from '$lib/types/menu';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
</script>

<div class="relative w-full max-w-5xl mx-auto aspect-[3/2] bg-primary overflow-hidden">
  {#if menu.coverImageUrl}
    <img src={menu.coverImageUrl} alt="" class="w-full h-full object-cover" />
  {:else}
    <div class="w-full h-full flex items-center justify-center">
      <h1 class="text-4xl font-bold text-surface">{name}</h1>
    </div>
  {/if}
  <div class="absolute inset-x-0 bottom-0 h-16
              bg-gradient-to-b from-transparent to-[var(--color-surface)]
              pointer-events-none"></div>
</div>
