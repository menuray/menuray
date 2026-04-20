<script lang="ts">
  import type { Locale, SpiceLevel } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { level, locale }: { level: SpiceLevel; locale: Locale } = $props();
  const pepperCount = $derived({ none: 0, mild: 1, medium: 2, hot: 3 }[level]);
  // spice keys are always one of the three valid StringKey values when level != 'none'
  const spiceKey = $derived(`spice.${level}` as Parameters<typeof t>[1]);
</script>

{#if pepperCount > 0}
  <div class="flex items-center gap-1 text-sm text-error" aria-label={t(locale, spiceKey)}>
    {#each Array(pepperCount) as _, i (i)}
      <span aria-hidden="true">🌶</span>
    {/each}
    <span class="ml-1">{t(locale, spiceKey)}</span>
  </div>
{/if}
