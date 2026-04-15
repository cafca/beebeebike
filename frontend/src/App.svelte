<script>
  import Map from './components/Map.svelte';
  import AuthModal from './components/AuthModal.svelte';
  import Toolbar from './components/Toolbar.svelte';
  import SearchBar from './components/SearchBar.svelte';
  import RoutePanel from './components/RoutePanel.svelte';
  import { auth, checkSession, logout } from './lib/auth.svelte.js';
  import { initOverlay } from './lib/overlay.js';
  import { initBrush, destroyBrush } from './lib/brush.svelte.js';
  import { initRouting } from './lib/routing.svelte.js';

  let map = $state(null);
  let authModalMode = $state('login');
  let showAuthModal = $state(false);

  checkSession();

  function handleMapLoad(m) {
    map = m;
  }

  $effect(() => {
    if (map && auth.user) {
      initOverlay(map);
      initBrush(map);
      initRouting(map);
      return () => destroyBrush();
    }
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

<Map onload={handleMapLoad} />

{#if auth.ready && auth.user}
  <SearchBar />
  <RoutePanel />
  <div class="user-bar">
    <span>{userLabel}</span>
    {#if auth.user.account_type === 'anonymous'}
      <button onclick={() => openAuth('register')}>Sign up</button>
      <button onclick={() => openAuth('login')}>Log in</button>
    {:else}
      <button onclick={logout}>Log out</button>
    {/if}
  </div>
  <Toolbar />
{/if}

{#if showAuthModal}
  <AuthModal initialMode={authModalMode} onclose={() => showAuthModal = false} />
{/if}

<style>
  .user-bar {
    position: absolute; top: 12px; right: 60px;
    background: white; padding: 8px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 10;
    display: flex; gap: 12px; align-items: center; font-size: 14px;
  }
  .user-bar button {
    background: none; border: none; color: #2563eb; cursor: pointer;
  }
</style>
