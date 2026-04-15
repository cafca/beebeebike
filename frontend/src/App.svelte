<script>
  import Map from './components/Map.svelte';
  import { api } from './lib/api.js';

  let map = $state(null);
  let user = $state(null);

  api.me().then(u => user = u).catch(() => {});

  function handleMapLoad(m) {
    map = m;
  }
</script>

<Map onload={handleMapLoad} />

{#if !user}
  <div class="auth-prompt">
    <p>Log in to start painting your map</p>
  </div>
{/if}

<style>
  .auth-prompt {
    position: absolute;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    background: white;
    padding: 12px 24px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    z-index: 10;
  }
</style>
