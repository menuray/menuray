<script lang="ts">
  import '../app.css';
  import MenurayBadge from '$lib/components/MenurayBadge.svelte';
  import type { Snippet } from 'svelte';

  let { children, data }: { children: Snippet; data?: { lang?: string } } = $props();
  const locale = $derived(data?.lang ?? 'en');
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

<MenurayBadge {locale} />
