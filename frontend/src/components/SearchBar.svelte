<script>
  import { api } from '../lib/api.js';
  import { route, computeRoute, clearRoute } from '../lib/routing.svelte.js';

  let query = $state('');
  let results = $state([]);
  let debounceTimer;
  let settingField = $state('origin');

  $effect(() => {
    settingField = route.origin ? 'destination' : 'origin';
  });

  function onInput() {
    clearTimeout(debounceTimer);
    if (query.length < 2) { results = []; return; }
    debounceTimer = setTimeout(async () => {
      try {
        const data = await api.geocode(query);
        results = (data.features || []).map(f => ({
          name: formatName(f.properties),
          lng: f.geometry.coordinates[0],
          lat: f.geometry.coordinates[1],
        }));
      } catch { results = []; }
    }, 300);
  }

  function formatName(props) {
    const streetLine = [props.street, props.housenumber].filter(Boolean).join(' ').trim();
    const locality = props.city || props.district || props.locality;
    const parts = [props.name, streetLine, locality].filter(Boolean);
    return parts.join(', ') || 'Unknown';
  }

  function select(result) {
    if (settingField === 'origin') {
      route.origin = result;
      settingField = 'destination';
    } else {
      route.destination = result;
      computeRoute();
    }
    query = '';
    results = [];
  }

  function handleClear() {
    clearRoute();
    settingField = 'origin';
  }
</script>

<div class="search-container">
  <div class="search-bar">
    {#if route.origin}
      <div class="waypoint">
        <span class="dot origin-dot"></span>
        <span>{route.origin.name}</span>
      </div>
    {/if}
    {#if route.destination}
      <div class="waypoint">
        <span class="dot dest-dot"></span>
        <span>{route.destination.name}</span>
      </div>
    {/if}

    {#if !route.destination}
      <input
        type="text"
        placeholder={settingField === 'origin' ? 'Search origin...' : 'Search destination...'}
        bind:value={query}
        oninput={onInput}
      />
    {/if}

    {#if route.origin}
      <button class="clear-btn" onclick={handleClear}>&times;</button>
    {/if}
  </div>

  {#if results.length > 0}
    <ul class="results">
      {#each results as result}
        <li>
          <button class="result-btn" onclick={() => select(result)}>{result.name}</button>
        </li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .search-container {
    position: absolute; top: 12px; left: 12px; z-index: 10;
    width: min(340px, calc(100vw - 24px));
  }
  .search-bar {
    background: white; border-radius: 8px; padding: 8px 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    display: flex; flex-direction: column; gap: 4px;
    position: relative;
  }
  input {
    border: none; outline: none; font-size: 14px; padding: 6px 0;
    width: 100%;
  }
  .waypoint {
    display: flex; align-items: center; gap: 8px; font-size: 13px;
    padding: 4px 0;
  }
  .dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .origin-dot { background: #22c55e; }
  .dest-dot { background: #ef4444; }
  .clear-btn {
    position: absolute; right: 8px; top: 8px;
    background: none; border: none; font-size: 18px; cursor: pointer; color: #666;
  }
  .results {
    list-style: none; margin: 4px 0 0; padding: 0; background: white;
    border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    max-height: 200px; overflow-y: auto;
  }
  .results li {
    border-bottom: 1px solid #f0f0f0;
  }
  .result-btn {
    width: 100%; text-align: left; padding: 10px 12px;
    background: none; border: none; cursor: pointer; font-size: 13px;
  }
  .result-btn:hover { background: #f0f4ff; }

  @media (max-width: 640px) {
    .result-btn {
      padding: 14px 12px;
    }
  }
</style>
