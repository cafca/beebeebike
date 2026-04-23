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
  import PreferencesPanel from './PreferencesPanel.svelte';

  let query = $state('');
  let results = $state([]);
  let debounceTimer;
  let settingField = $state('origin');
  let homeActionError = $state('');
  let showPreferences = $state(false);

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
          iconType: getIconType(f.properties),
        }));
      } catch { results = []; }
    }, 300);
  }

  function getIconType(props) {
    if (props.housenumber) return null;
    const key = props.osm_key;
    const val = props.osm_value;
    if (key === 'highway' && val !== 'bus_stop') return null;
    if (key === 'railway' || key === 'public_transport') return 'train';
    if (key === 'highway' && val === 'bus_stop') return 'bus';
    if (key === 'aeroway') return 'airport';
    if (key === 'place' || key === 'boundary') return 'place';
    if (key === 'amenity' && (val === 'restaurant' || val === 'fast_food')) return 'restaurant';
    if (key === 'amenity' && (val === 'cafe' || val === 'coffee_shop')) return 'cafe';
    return 'poi';
  }

  function formatName(props) {
    const streetLine = [props.street, props.housenumber].filter(Boolean).join(' ').trim();
    const parts = [props.name, streetLine, props.postcode].filter(Boolean);
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
    <div class="panel-actions">
      <button
        class="icon-btn"
        class:active={showPreferences}
        aria-label="Preferences"
        aria-pressed={showPreferences}
        title="Preferences"
        onclick={() => showPreferences = !showPreferences}
      >
        <svg viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
          <circle cx="12" cy="12" r="3"/>
          <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1A2 2 0 1 1 4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.3 7A2 2 0 1 1 7.1 4.2l.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.6V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1A2 2 0 1 1 19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.1a2 2 0 1 1 0 4H21a1.7 1.7 0 0 0-1.6 1Z"/>
        </svg>
      </button>

      {#if route.origin && (!locations.startAtHome || route.destination || route.data || route.origin.savedLocationName !== 'home')}
        <button class="icon-btn clear-btn" onclick={handleClear} title="Clear route" aria-label="Clear route">&times;</button>
      {/if}
    </div>

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

    {#if showPreferences}
      <PreferencesPanel />
    {/if}
  </div>

  {#if results.length > 0}
    <ul class="results">
      {#each results as result}
        <li>
          <button class="result-btn" onclick={() => select(result)}>
            {#if result.iconType === 'train'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <rect x="3" y="1.5" width="10" height="9" rx="2"/>
                <line x1="3" y1="7" x2="13" y2="7"/>
                <circle cx="5.5" cy="12.5" r="1.2" fill="currentColor" stroke="none"/>
                <circle cx="10.5" cy="12.5" r="1.2" fill="currentColor" stroke="none"/>
                <line x1="3" y1="14.5" x2="13" y2="14.5"/>
                <line x1="5.5" y1="11.5" x2="4.5" y2="14.5"/>
                <line x1="10.5" y1="11.5" x2="11.5" y2="14.5"/>
              </svg>
            {:else if result.iconType === 'bus'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <rect x="2" y="3" width="12" height="9" rx="2"/>
                <line x1="2" y1="7" x2="14" y2="7"/>
                <circle cx="4.5" cy="13.5" r="1.2" fill="currentColor" stroke="none"/>
                <circle cx="11.5" cy="13.5" r="1.2" fill="currentColor" stroke="none"/>
                <line x1="5.5" y1="12" x2="5.5" y2="12"/>
                <line x1="8" y1="3" x2="8" y2="1"/>
              </svg>
            {:else if result.iconType === 'airport'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M8 2 L13 9 L8 7.5 L3 9 Z"/>
                <line x1="8" y1="7.5" x2="8" y2="13"/>
                <line x1="5.5" y1="12" x2="10.5" y2="12"/>
              </svg>
            {:else if result.iconType === 'place'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M8 2a4 4 0 0 1 4 4c0 3-4 8-4 8S4 9 4 6a4 4 0 0 1 4-4z"/>
                <circle cx="8" cy="6" r="1.5" fill="currentColor" stroke="none"/>
              </svg>
            {:else if result.iconType === 'restaurant'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <line x1="5" y1="1" x2="5" y2="6"/>
                <path d="M3 1 v4 a2 2 0 0 0 4 0 V1"/>
                <line x1="5" y1="8" x2="5" y2="15"/>
                <line x1="11" y1="1" x2="11" y2="15"/>
                <path d="M9 1 v5 a2 2 0 0 0 4 0 V1"/>
              </svg>
            {:else if result.iconType === 'cafe'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M3 5 h8 l-1 7 H4 Z"/>
                <path d="M11 6 h1.5 a1.5 1.5 0 0 1 0 3 H11"/>
                <line x1="2" y1="14" x2="12" y2="14"/>
              </svg>
            {:else if result.iconType === 'poi'}
              <svg class="result-icon" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <circle cx="8" cy="8" r="5.5"/>
                <circle cx="8" cy="8" r="2" fill="currentColor" stroke="none"/>
              </svg>
            {/if}
            {result.name}
          </button>
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
    background: var(--panel);
    border-radius: 20px;
    padding: 10px 14px;
    box-shadow: var(--shadow-panel);
    display: flex;
    flex-direction: column;
    gap: 4px;
    position: relative;
  }
  .panel-actions {
    position: absolute;
    top: 50%;
    right: 6px;
    transform: translateY(-50%);
    display: flex;
    gap: 4px;
    z-index: 2;
  }
  .icon-btn {
    width: 34px;
    height: 34px;
    padding: 0;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--ink-muted);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  .icon-btn:hover,
  .icon-btn.active {
    background: var(--brand-soft);
    color: var(--brand);
  }
  input {
    border: none;
    outline: none;
    background: transparent;
    font: 500 15px/1.4 var(--font-sans);
    color: var(--ink);
    padding: 6px 0;
    width: calc(100% - 84px);
  }
  input::placeholder {
    color: var(--ink-faint);
  }
  .waypoint {
    display: flex;
    align-items: center;
    gap: 8px;
    font: 600 14px/1.3 var(--font-sans);
    color: var(--ink);
    padding: 4px 84px 4px 0;
  }
  .dot {
    width: 10px;
    height: 10px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .origin-dot { background: var(--brand); }
  .dest-dot { background: var(--route-ink); }
  .clear-btn {
    font-size: 18px;
    line-height: 1;
  }
  .save-home-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    width: 100%;
    min-height: 34px;
    margin-top: 4px;
    padding: 8px 12px;
    border: 1px solid var(--divider);
    border-radius: var(--radius-ctrl);
    background: var(--panel);
    color: var(--ink);
    cursor: pointer;
    font: 600 13px/1.3 var(--font-sans);
  }
  .save-home-btn:hover {
    background: var(--bg);
  }
  .save-home-btn:disabled {
    opacity: 0.55;
    cursor: default;
  }
  .save-home-btn svg {
    width: 16px;
    height: 16px;
    fill: currentColor;
    flex: 0 0 auto;
  }
  .home-control {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 12px;
    min-height: 32px;
    margin-top: 2px;
  }
  .home-toggle {
    display: flex;
    align-items: center;
    gap: 8px;
    color: var(--ink);
    font: 500 13px/1.3 var(--font-sans);
    cursor: pointer;
    user-select: none;
  }
  .home-toggle input {
    position: absolute;
    opacity: 0;
    pointer-events: none;
  }
  .switch {
    width: 34px;
    height: 20px;
    border-radius: 999px;
    background: var(--ink-faint);
    position: relative;
    flex: 0 0 auto;
    transition: background 0.15s;
  }
  .switch::after {
    content: '';
    position: absolute;
    width: 16px;
    height: 16px;
    top: 2px;
    left: 2px;
    border-radius: 50%;
    background: var(--panel);
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.22);
    transition: transform 0.15s;
  }
  .home-toggle input:checked + .switch { background: var(--brand); }
  .home-toggle input:checked + .switch::after { transform: translateX(14px); }
  .home-toggle input:focus-visible + .switch {
    outline: 2px solid var(--brand);
    outline-offset: 2px;
  }
  .reset-home-btn {
    background: none;
    border: none;
    color: var(--brand);
    cursor: pointer;
    font: 600 13px/1.3 var(--font-sans);
    padding: 4px 0;
  }
  .reset-home-btn:disabled { opacity: 0.55; cursor: default; }
  .home-error {
    color: #b91c1c;
    font: 500 12px/1.3 var(--font-sans);
    padding: 2px 0;
  }
  .results {
    list-style: none;
    margin: 4px 0 0;
    padding: 0;
    background: var(--panel);
    border-radius: var(--radius-ctrl);
    box-shadow: var(--shadow-panel);
    max-height: 200px;
    overflow-y: auto;
  }
  .results li {
    border-bottom: 1px solid var(--divider);
  }
  .results li:last-child {
    border-bottom: none;
  }
  .result-btn {
    width: 100%;
    text-align: left;
    padding: 10px 12px;
    background: none;
    border: none;
    cursor: pointer;
    font: 500 13px/1.3 var(--font-sans);
    color: var(--ink);
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .result-btn:hover { background: var(--brand-soft); }
  .result-icon {
    width: 14px;
    height: 14px;
    flex-shrink: 0;
    color: var(--ink-faint);
  }

  @media (max-width: 640px) {
    .search-container {
      width: 100%;
    }
    .search-bar {
      background: none;
      box-shadow: none;
      border-radius: var(--radius-ctrl) var(--radius-ctrl) 0 0;
    }
    .result-btn {
      padding: 14px 12px;
    }
  }
</style>
