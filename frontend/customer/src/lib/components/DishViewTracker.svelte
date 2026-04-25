<script lang="ts">
  import { onMount } from 'svelte';
  import type { Snippet } from 'svelte';
  import { getOrCreateSessionId } from '$lib/session/session';
  import { logDishView } from '$lib/data/logDishView';

  let {
    menuId,
    dishId,
    enabled,
    qrVariant = null,
    children,
  }: {
    menuId: string;
    dishId: string;
    enabled: boolean;
    qrVariant?: string | null;
    children: Snippet;
  } = $props();

  let el: HTMLElement;
  let fired = false;

  onMount(() => {
    if (!enabled) return;
    let timer: number | undefined;
    const io = new IntersectionObserver((entries) => {
      const visible = entries.some((e) => e.isIntersecting);
      if (visible && !fired) {
        timer = window.setTimeout(() => {
          if (fired) return;
          fired = true;
          logDishView({
            menuId,
            dishId,
            sessionId: getOrCreateSessionId(),
            qrVariant,
          });
        }, 2000);
      } else if (timer) {
        clearTimeout(timer);
        timer = undefined;
      }
    }, { threshold: 0.5 });
    io.observe(el);
    return () => {
      io.disconnect();
      if (timer) clearTimeout(timer);
    };
  });
</script>

<div bind:this={el}>
  {@render children()}
</div>
