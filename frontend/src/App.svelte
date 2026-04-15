<script>
  import Map from './components/Map.svelte';
  import AuthModal from './components/AuthModal.svelte';
  import Toolbar from './components/Toolbar.svelte';
  import { auth, checkSession, logout } from './lib/auth.svelte.js';
  import { initOverlay } from './lib/overlay.js';
  import { initBrush, destroyBrush } from './lib/brush.svelte.js';

  let map = $state(null);

  checkSession();

  function handleMapLoad(m) {
    map = m;
  }

  $effect(() => {
    if (map && auth.user) {
      initOverlay(map);
      initBrush(map);
      return () => destroyBrush();
    }
  });
</script>

<Map onload={handleMapLoad} />

{#if auth.user}
  <div class="user-bar">
    <span>{auth.user.display_name || auth.user.email}</span>
    <button onclick={logout}>Log out</button>
  </div>
  <Toolbar />
{:else}
  <AuthModal />
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
