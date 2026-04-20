<script lang="ts">
  import { page } from '$app/state';
  import { t } from '$lib/i18n/strings';
  const locale = 'en';
  const is410 = $derived(page.status === 410);
  const titleKey = $derived(is410 ? 'error.gone.title' : 'error.notFound.title');
  const bodyKey = $derived(is410 ? 'error.gone.body' : 'error.notFound.body');
</script>

<main class="min-h-dvh flex flex-col items-center justify-center p-8 text-center gap-4">
  <h1 class="text-2xl font-semibold text-ink">{t(locale, titleKey)}</h1>
  <p class="text-secondary max-w-md">{t(locale, bodyKey)}</p>
  <a href="https://menuray.com" class="text-primary underline underline-offset-4">menuray.com</a>
</main>
