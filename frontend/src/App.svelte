<script>
  import Map from './components/Map.svelte';
  import AuthModal from './components/AuthModal.svelte';
  import WelcomeModal from './components/WelcomeModal.svelte';
  import Toolbar from './components/Toolbar.svelte';
  import SearchBar from './components/SearchBar.svelte';
  import RoutePanel from './components/RoutePanel.svelte';
  import ZoomControls from './components/ZoomControls.svelte';
  import { untrack } from 'svelte';
  import { auth, checkSession, logout } from './lib/auth.svelte.js';
  import { loadHomeLocation, locations } from './lib/locations.svelte.js';
  import { initOverlay } from './lib/overlay.js';
  import { initBrush, destroyBrush } from './lib/brush.svelte.js';
  import { applyStartAtHome, centerOnHome, clearRoute, initRouting, syncHomeMarker } from './lib/routing.svelte.js';

  let map = $state(null);
  let authModalMode = $state('login');
  let loadedLocationsForUser = $state(null);
  let showAuthModal = $state(false);
  let initialHomeLoaded = $state(false);

  checkSession().then(() => {
    if (auth.user) {
      loadHomeLocation()
        .then(() => { initialHomeLoaded = true; })
        .catch(() => { initialHomeLoaded = true; });
    } else {
      initialHomeLoaded = true;
    }
  });

  let mapCenter = $derived(
    locations.home ? [locations.home.lng, locations.home.lat] : null
  );
  let mapZoom = $derived(locations.home ? 14 : undefined);

  function handleMapLoad(m) {
    map = m;
  }

  $effect(() => {
    if (map && auth.user) {
      untrack(() => {
        initOverlay(map);
        initBrush(map);
        initRouting(map);
      });
      return () => destroyBrush();
    }
  });

  $effect(() => {
    const userId = auth.user?.id;
    if (!userId || !map) {
      loadedLocationsForUser = null;
      return;
    }
    if (loadedLocationsForUser === userId) return;

    const isFirstUser = loadedLocationsForUser === null;
    loadedLocationsForUser = userId;

    if (isFirstUser && initialHomeLoaded) {
      // Initial page load — home was pre-loaded and map already centered
      syncHomeMarker();
      clearRoute();
    } else {
      // User switched (login/logout) — reload home and jump to it
      loadHomeLocation()
        .then(() => {
          syncHomeMarker();
          clearRoute();
          centerOnHome(map);
        })
        .catch((e) => console.error('Failed to load home location:', e));
    }
  });

  $effect(() => {
    locations.home;
    locations.startAtHome;
    if (!map) return;
    syncHomeMarker();
    applyStartAtHome();
  });

  function openAuth(mode) {
    authModalMode = mode;
    showAuthModal = true;
  }

  let userLabel = $derived(
    auth.user?.account_type === 'anonymous'
      ? 'Guest'
      : (auth.user?.display_name || auth.user?.email || 'Guest')
  );
</script>

{#if initialHomeLoaded}
  <Map onload={handleMapLoad} center={mapCenter} zoom={mapZoom} />
{/if}
<ZoomControls {map} />

{#if auth.ready && auth.user}
  <div class="top-panel">
    <div class="search-stack">
      <SearchBar />
      <RoutePanel />
    </div>
    <div class="user-bar">
      <span>{userLabel}</span>
      {#if auth.user.account_type === 'anonymous'}
        <button onclick={() => openAuth('register')}>Sign up</button>
        <button onclick={() => openAuth('login')}>Log in</button>
      {:else}
        <button onclick={logout}>Log out</button>
      {/if}
    </div>
  </div>
  <Toolbar />
{/if}

{#if showAuthModal}
  <AuthModal initialMode={authModalMode} onclose={() => showAuthModal = false} />
{/if}

{#if auth.ready && auth.isNewSession}
  <WelcomeModal onclose={() => auth.isNewSession = false} />
{/if}

<style>
  .top-panel {
    position: absolute;
    top: 12px;
    left: 12px;
    right: 60px;
    z-index: 10;
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    justify-content: space-between;
    gap: 8px;
  }
  .search-stack {
    display: flex;
    flex-direction: row;
    align-items: flex-start;
    gap: 8px;
  }
  .user-bar {
    background: white; padding: 8px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    display: flex; gap: 12px; align-items: center; font-size: 14px;
    white-space: nowrap;
  }
  .user-bar button {
    background: none; border: none; color: #2563eb; cursor: pointer;
  }

  @media (max-width: 640px) {
    .top-panel {
      right: 12px;
      flex-direction: column;
      gap: 0;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    }
    .search-stack {
      flex-direction: column;
      width: 100%;
    }
    .user-bar {
      width: 100%;
      box-sizing: border-box;
      padding: 6px 12px;
      gap: 8px;
      font-size: 12px;
      background: none;
      box-shadow: none;
      border-radius: 0 0 8px 8px;
      border-top: 1px solid #f0f0f0;
    }
  }
</style>
