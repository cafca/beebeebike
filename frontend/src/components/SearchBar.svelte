<script>
  import { api } from '../lib/api.js';
  import {
    route,
    applyStartAtHome,
    computeRoute,
    clearRoute,
    syncHomeMarker,
  } from '../lib/routing.svelte.js';
  import {
    locations,
    resetHomeLocation,
    routePointFromLocation,
    saveHomeLocation,
    setStartAtHome,
  } from '../lib/locations.svelte.js';

  let query = $state('');
  let results = $state([]);
  let debounceTimer;
  let settingField = $state('origin');
  let homeActionError = $state('');

  $effect(() => {
    settingField = route.origin ? 'destination' : 'origin';
  });

  let canSaveHome = $derived(
    route.origin && !locations.home && route.origin.savedLocationName !== 'home'
  );

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
    if (locations.startAtHome && locations.home && !route.origin) {
      route.origin = routePointFromLocation(locations.home);
      route.destination = result;
      computeRoute();
    } else if (settingField === 'origin') {
      route.origin = result;
      settingField = 'destination';
    } else {
      route.destination = result;
      computeRoute();
    }
    query = '';
    results = [];
  }

  async function handleSaveHome() {
    homeActionError = '';
    try {
      const home = await saveHomeLocation(route.origin);
      route.origin = routePointFromLocation(home);
      syncHomeMarker();
    } catch (e) {
      homeActionError = e.message;
    }
  }

  function handleStartAtHomeChange(event) {
    setStartAtHome(event.currentTarget.checked);
    if (locations.startAtHome) {
      clearRoute();
      applyStartAtHome();
    } else if (route.origin?.savedLocationName === 'home' && !route.destination && !route.data) {
      route.origin = null;
    }
  }

  async function handleResetHome() {
    homeActionError = '';
    try {
      await resetHomeLocation();
      clearRoute();
      syncHomeMarker();
    } catch (e) {
      homeActionError = e.message;
    }
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

    {#if canSaveHome}
      <button class="save-home-btn" onclick={handleSaveHome} disabled={locations.saving}>
        <svg viewBox="0 0 20 20" aria-hidden="true">
          <path d="M3 9.1 10 3l7 6.1-1.2 1.4L10 5.4l-5.8 5.1L3 9.1Z" />
          <path d="M5 9.6 10 5.2l5 4.4V16a1 1 0 0 1-1 1h-2.8v-4.5H8.8V17H6a1 1 0 0 1-1-1V9.6Z" />
        </svg>
        <span>{locations.saving ? 'Saving...' : 'Save start as home'}</span>
      </button>
    {:else if locations.home}
      <div class="home-control">
        <label class="home-toggle">
          <input
            type="checkbox"
            checked={locations.startAtHome}
            onchange={handleStartAtHomeChange}
          />
          <span class="switch" aria-hidden="true"></span>
          <span>Start at home</span>
        </label>
        <button class="reset-home-btn" onclick={handleResetHome} disabled={locations.saving}>
          reset
        </button>
      </div>
    {/if}

    {#if homeActionError}
      <div class="home-error">{homeActionError}</div>
    {/if}

    {#if route.origin && (!locations.startAtHome || route.destination || route.data || route.origin.savedLocationName !== 'home')}
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
    width: 340px;
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
  .save-home-btn {
    display: flex; align-items: center; justify-content: center; gap: 6px;
    width: 100%; min-height: 32px; margin-top: 2px; padding: 7px 10px;
    border: 1px solid #d1d5db; border-radius: 6px; background: #f9fafb;
    color: #111827; cursor: pointer; font-size: 13px; font-weight: 600;
  }
  .save-home-btn:hover { background: #f3f4f6; }
  .save-home-btn:disabled { opacity: 0.55; cursor: default; }
  .save-home-btn svg {
    width: 16px; height: 16px; fill: currentColor; flex: 0 0 auto;
  }
  .home-control {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    min-height: 32px; margin-top: 2px;
  }
  .home-toggle {
    display: flex; align-items: center; gap: 8px; color: #111827;
    font-size: 13px; cursor: pointer; user-select: none;
  }
  .home-toggle input {
    position: absolute; opacity: 0; pointer-events: none;
  }
  .switch {
    width: 34px; height: 20px; border-radius: 999px; background: #d1d5db;
    position: relative; flex: 0 0 auto; transition: background 0.15s;
  }
  .switch::after {
    content: ''; position: absolute; width: 16px; height: 16px; top: 2px; left: 2px;
    border-radius: 50%; background: white; box-shadow: 0 1px 2px rgba(0,0,0,0.22);
    transition: transform 0.15s;
  }
  .home-toggle input:checked + .switch { background: #2563eb; }
  .home-toggle input:checked + .switch::after { transform: translateX(14px); }
  .home-toggle input:focus-visible + .switch {
    outline: 2px solid #2563eb; outline-offset: 2px;
  }
  .reset-home-btn {
    background: none; border: none; color: #2563eb; cursor: pointer;
    font-size: 13px; padding: 4px 0;
  }
  .reset-home-btn:disabled { opacity: 0.55; cursor: default; }
  .home-error {
    color: #b91c1c; font-size: 12px; line-height: 1.3; padding: 2px 0;
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
    .search-container {
      width: 100%;
    }
    .result-btn {
      padding: 14px 12px;
    }
  }
</style>
