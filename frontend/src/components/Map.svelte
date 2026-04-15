<script>
  import { createMap } from '../lib/map.js';

  let { onload } = $props();
  let container = $state();
  let map = $state();

  $effect(() => {
    if (container && !map) {
      map = createMap(container);
      map.on('load', () => onload?.(map));
      return () => map?.remove();
    }
  });
</script>

<div bind:this={container} class="map-container"></div>

<style>
  .map-container {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
  }
</style>
