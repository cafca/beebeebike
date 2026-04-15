<script>
  import { login, register } from '../lib/auth.svelte.js';

  let { initialMode = 'login', onclose = () => {} } = $props();

  let mode = $state('login');
  let email = $state('');
  let password = $state('');
  let displayName = $state('');
  let error = $state('');
  let loading = $state(false);

  $effect(() => {
    mode = initialMode;
  });

  async function handleSubmit() {
    error = '';
    loading = true;
    try {
      if (mode === 'login') {
        await login(email, password);
      } else {
        await register(email, password, displayName);
      }
      onclose();
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }
</script>

<div class="overlay">
  <div class="modal">
    <button class="close" type="button" onclick={onclose} title="Close">&times;</button>
    <h2>{mode === 'login' ? 'Log In' : 'Sign Up'}</h2>

    <form onsubmit={e => { e.preventDefault(); handleSubmit(); }}>
      {#if mode === 'register'}
        <input type="text" placeholder="Display name" bind:value={displayName} />
      {/if}
      <input type="email" placeholder="Email" bind:value={email} required />
      <input type="password" placeholder="Password (min 8 chars)" bind:value={password} required minlength="8" />

      {#if error}<p class="error">{error}</p>{/if}

      <button type="submit" disabled={loading}>
        {loading ? '...' : (mode === 'login' ? 'Log In' : 'Sign Up')}
      </button>
    </form>

    <p class="switch">
      {#if mode === 'login'}
        No account? <button class="link" onclick={() => mode = 'register'}>Sign up</button>
      {:else}
        Have an account? <button class="link" onclick={() => mode = 'login'}>Log in</button>
      {/if}
    </p>
  </div>
</div>

<style>
  .overlay {
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal {
    position: relative;
    background: white; padding: 32px; border-radius: 12px; min-width: min(320px, calc(100vw - 32px));
    box-shadow: 0 4px 24px rgba(0,0,0,0.2);
  }
  .close {
    position: absolute; top: 10px; right: 10px;
    width: 28px; height: 28px; border: none; border-radius: 6px;
    background: white; cursor: pointer; font-size: 20px; line-height: 1;
  }
  h2 { margin-bottom: 16px; }
  form { display: flex; flex-direction: column; gap: 12px; }
  input {
    padding: 10px 12px; border: 1px solid #ccc; border-radius: 6px; font-size: 14px;
  }
  button[type="submit"] {
    padding: 10px; background: #2563eb; color: white; border: none;
    border-radius: 6px; cursor: pointer; font-size: 14px;
  }
  button[type="submit"]:disabled { opacity: 0.5; }
  .error { color: #dc2626; font-size: 13px; margin: 0; }
  .switch { margin-top: 12px; font-size: 13px; text-align: center; }
  .link { background: none; border: none; color: #2563eb; cursor: pointer; text-decoration: underline; }

  @media (max-width: 640px) {
    .modal {
      padding: 24px 20px;
    }
  }
</style>
