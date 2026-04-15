<script>
  import { route } from '../lib/routing.svelte.js';

  function formatDist(meters) {
    return meters >= 1000
      ? `${(meters / 1000).toFixed(1)} km`
      : `${Math.round(meters)} m`;
  }

  function formatTime(ms) {
    const minutes = Math.round(ms / 60000);
    return minutes >= 60
      ? `${Math.floor(minutes / 60)}h ${minutes % 60}m`
      : `${minutes} min`;
  }
</script>

{#if route.loading}
  <div class="route-panel">Computing route...</div>
{:else if route.data}
  <div class="route-panel">
    <span>{formatDist(route.data.distance)}</span>
    <span class="sep">&middot;</span>
    <span>{formatTime(route.data.time)}</span>
  </div>
{/if}

<style>
  .route-panel {
    background: white; padding: 10px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    font-size: 14px; display: flex; gap: 4px;
    white-space: nowrap;
  }
  .sep { color: #999; }
</style>
