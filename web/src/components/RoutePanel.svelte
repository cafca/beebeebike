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
  <div class="route-panel">
    <span class="spinner" aria-hidden="true"></span>
    <span>Computing route...</span>
  </div>
{:else if route.data}
  <div class="route-panel">
    <span>{formatDist(route.data.distance)}</span>
    <span class="sep">&middot;</span>
    <span>{formatTime(route.data.time)}</span>
  </div>
{/if}

<style>
  .route-panel {
    background: var(--panel);
    padding: 10px 16px;
    border-radius: var(--radius-panel);
    box-shadow: var(--shadow-panel);
    font: 600 12px/1.3 var(--font-mono);
    color: var(--ink-muted);
    display: flex;
    gap: 8px;
    align-items: center;
    white-space: nowrap;
  }
  .sep { color: var(--ink-faint); }
  .spinner {
    width: 14px;
    height: 14px;
    border-radius: 50%;
    border: 2px solid var(--divider);
    border-top-color: var(--brand);
    animation: spin 0.8s linear infinite;
    display: inline-block;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
