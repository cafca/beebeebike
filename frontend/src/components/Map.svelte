<script>
  import { createMap } from '../lib/map.js';

  let { onload } = $props();
  let container = $state();
  let map = $state();

  $effect(() => {
    if (!container) return;

    let disposed = false;
    let mountedMap;

    createMap(container)
      .then((createdMap) => {
        if (disposed) {
          createdMap.remove();
          return;
        }

        mountedMap = createdMap;
        map = createdMap;
        if (createdMap.loaded()) {
          onload?.(createdMap);
        } else {
          createdMap.once('load', () => onload?.(createdMap));
        }
      })
      .catch((error) => {
        console.error('Failed to initialize map:', error);
      });

    return () => {
      disposed = true;
      mountedMap?.remove();
      map = undefined;
    };
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
