<script lang="ts">
  let { data }: { data: { token?: string; result?: { ok: boolean; code?: string; storeId?: string } } } = $props();

  function openInApp() {
    if (!data.token) return;
    window.location.href = `menuraymerchant://accept-invite?token=${encodeURIComponent(data.token)}`;
  }
</script>

<svelte:head>
  <title>Accept invite · MenuRay</title>
  <meta name="robots" content="noindex,nofollow" />
</svelte:head>

<div class="mx-auto max-w-md px-6 py-16 text-ink">
  <h1 class="mb-4 text-2xl font-semibold">You've been invited to MenuRay</h1>

  {#if data.result && !data.result.ok}
    <p class="mb-6">This invite link is invalid or has expired. Please ask the person who invited you for a new link.</p>
  {:else if data.token}
    <p class="mb-6">Open the MenuRay merchant app to accept this invite.</p>
    <button class="rounded-xl bg-primary px-5 py-3 text-white font-medium"
            onclick={openInApp}>Open MenuRay app</button>
    <p class="mt-8 text-sm text-secondary">
      Don't have the app yet? Download it and sign in, then tap the invite link again.
    </p>
  {/if}
</div>
