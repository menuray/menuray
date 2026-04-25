<script lang="ts">
  import type { PageData } from './$types';
  import { resolveTemplate } from '$lib/templates/registry';
  import { storeName } from '$lib/types/menu';

  let { data }: { data: PageData } = $props();
  const menu = $derived(data.menu);
  const locale = $derived(data.lang);

  const title = $derived(`${storeName(menu.store, locale)} — ${menu.name} | MenuRay`);
  const description = $derived(
    `${menu.categories.length} categories, ${menu.categories.reduce((n, c) => n + c.dishes.length, 0)} dishes`,
  );

  const Template = $derived(resolveTemplate(menu.templateId));
</script>

<svelte:head>
  <title>{title}</title>
  <meta name="description" content={description} />
  {#if menu.coverImageUrl}
    <meta property="og:image" content={menu.coverImageUrl} />
  {/if}
  <meta property="og:title" content={title} />
  <meta property="og:locale" content={locale} />
  {@html `<script type="application/ld+json">${JSON.stringify(data.jsonLd)}</` + `script>`}
  {#if menu.themeOverrides.primaryColor}
    {@html `<style>:root{--color-primary:${menu.themeOverrides.primaryColor};}</style>`}
  {/if}
</svelte:head>

<Template {data} />
