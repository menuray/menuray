<script lang="ts">
  import type { PublishedMenu, Locale } from '$lib/types/menu';
  import { storeName, storeAddress } from '$lib/types/menu';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
  const address = $derived(storeAddress(menu.store, locale));
</script>

<header class="bg-surface border-b border-divider">
  <div class="max-w-3xl mx-auto px-4 py-6 flex items-start gap-4">
    {#if menu.store.logoUrl}
      <img src={menu.store.logoUrl} alt="" class="w-14 h-14 rounded-xl object-cover bg-divider" />
    {/if}
    <div class="flex-1 min-w-0">
      <h1 class="text-xl font-semibold text-ink truncate">{name}</h1>
      {#if address}
        <p class="text-sm text-secondary truncate">{address}</p>
      {/if}
      <p class="text-sm text-primary mt-1">{menu.name}</p>
    </div>
  </div>
</header>
