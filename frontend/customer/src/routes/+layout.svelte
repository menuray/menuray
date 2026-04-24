<script lang="ts">
  import '../app.css';
  import MenurayBadge from '$lib/components/MenurayBadge.svelte';
  import type { Snippet } from 'svelte';

  type LayoutData = { lang?: string; menu?: { store?: { tier?: string } } };
  let { children, data }: { children: Snippet; data?: LayoutData } = $props();
  const locale = $derived(data?.lang ?? 'en');
  const badgeHidden = $derived(
    data?.menu?.store?.tier !== undefined &&
    data.menu.store.tier !== 'free'
  );
</script>

<svelte:head>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
  <link
    rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Noto+Sans+SC:wght@400;500;600;700&display=swap"
  />
</svelte:head>

{@render children()}

<MenurayBadge {locale} hidden={badgeHidden} />
