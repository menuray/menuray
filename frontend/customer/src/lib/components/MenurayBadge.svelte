<script lang="ts">
  import type { Locale } from '$lib/types/menu';
  import { t } from '$lib/i18n/strings';

  let { locale, hidden = false }: { locale: Locale; hidden?: boolean } = $props();
  const href = 'https://menuray.com/?utm_source=menu&utm_medium=customer_view&utm_campaign=powered_by';
</script>

{#if !hidden}
  <a
    {href}
    target="_blank"
    rel="noopener noreferrer"
    class="fixed bottom-0 left-0 right-0 z-50 flex items-center justify-center h-8
           bg-surface border-t border-divider text-secondary text-xs
           hover:text-primary transition-colors"
  >
    {t(locale, 'badge.poweredBy')}
  </a>
{/if}
