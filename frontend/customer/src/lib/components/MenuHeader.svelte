<script lang="ts">
  import type { PublishedMenu, Locale, TimeSlot } from '$lib/types/menu';
  import { storeName, storeAddress } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';
  import LangDropdown from './LangDropdown.svelte';

  let { menu, locale }: { menu: PublishedMenu; locale: Locale } = $props();
  const name = $derived(storeName(menu.store, locale));
  const address = $derived(storeAddress(menu.store, locale));

  // all_day → no badge (default state); other slots map to a localized label.
  function timeSlotLabel(slot: TimeSlot, l: Locale): string | null {
    switch (slot) {
      case 'lunch':    return t(l, 'timeSlot.lunch');
      case 'dinner':   return t(l, 'timeSlot.dinner');
      case 'seasonal': return t(l, 'timeSlot.seasonal');
      case 'all_day':
      default:         return null;
    }
  }
  const slotLabel = $derived(timeSlotLabel(menu.timeSlot, locale));
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
      <div class="mt-1 flex items-center gap-2 flex-wrap">
        <p class="text-sm text-primary truncate">{menu.name}</p>
        {#if slotLabel}
          <span
            class="inline-flex items-center text-xs font-medium px-2 py-0.5 rounded-full bg-primary/10 text-primary whitespace-nowrap"
            data-testid="time-slot-badge"
          >{slotLabel}{#if menu.timeSlotDescription}
            <span class="ml-1 text-secondary">· {menu.timeSlotDescription}</span>
          {/if}</span>
        {/if}
      </div>
    </div>
    {#if menu.availableLocales.length > 1}
      <LangDropdown {locale} available={menu.availableLocales} />
    {/if}
  </div>
</header>
