<script lang="ts">
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import type { Locale } from '$lib/types/menu';

  let {
    locale,
    available,
  }: {
    locale: Locale;
    available: Locale[];
  } = $props();

  const LABELS: Record<string, string> = {
    en: 'English',
    'zh-CN': '中文',
    ja: '日本語',
    ko: '한국어',
    es: 'Español',
    fr: 'Français',
  };

  function label(l: Locale): string {
    return LABELS[l] ?? l;
  }

  async function pick(next: Locale) {
    if (typeof localStorage !== 'undefined') localStorage.setItem('menuray.lang', next);
    const url = new URL(page.url);
    url.searchParams.set('lang', next);
    await goto(url.pathname + '?' + url.searchParams.toString(), { noScroll: true, replaceState: true });
  }

  let open = $state(false);
</script>

<div class="relative">
  <button
    type="button"
    onclick={() => (open = !open)}
    class="h-9 px-3 rounded-button border border-divider text-sm text-ink
           hover:border-primary transition-colors flex items-center gap-1"
    aria-haspopup="listbox"
    aria-expanded={open}
  >
    {label(locale)}
    <span aria-hidden="true" class="text-secondary">▾</span>
  </button>
  {#if open}
    <ul
      class="absolute right-0 top-full mt-1 z-40 min-w-36 py-1 rounded-button
             bg-surface border border-divider shadow-lg"
      role="listbox"
    >
      {#each available as l (l)}
        <li>
          <button
            type="button"
            onclick={() => { open = false; pick(l); }}
            class="w-full text-left px-3 py-1.5 text-sm hover:bg-divider/40
                   {l === locale ? 'text-primary font-medium' : 'text-ink'}"
            role="option"
            aria-selected={l === locale}
          >
            {label(l)}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
