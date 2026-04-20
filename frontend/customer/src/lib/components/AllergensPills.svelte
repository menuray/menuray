<script lang="ts">
  let { allergens }: { allergens: string[] } = $props();
</script>

{#if allergens.length > 0}
  <div class="flex flex-wrap gap-1.5" aria-label="allergens">
    {#each allergens as a (a)}
      <span class="text-xs px-2 py-0.5 rounded-full border border-divider text-secondary bg-surface">
        {a}
      </span>
    {/each}
  </div>
{/if}
