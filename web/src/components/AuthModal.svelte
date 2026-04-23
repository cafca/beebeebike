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
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(20, 40, 50, 0.4);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 100;
  }
  .modal {
    position: relative;
    background: var(--panel);
    padding: 32px;
    border-radius: var(--radius-panel);
    min-width: min(320px, calc(100vw - 32px));
    box-shadow: var(--shadow-panel);
    color: var(--ink);
    font-family: var(--font-sans);
  }
  .close {
    position: absolute;
    top: 10px;
    right: 10px;
    width: 32px;
    height: 32px;
    border: none;
    border-radius: var(--radius-fab);
    background: var(--bg);
    color: var(--ink-muted);
    cursor: pointer;
    font-size: 20px;
    line-height: 1;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  .close:hover {
    color: var(--ink);
  }
  h2 {
    margin-bottom: 16px;
    font: 600 17px/1.3 var(--font-sans);
    color: var(--ink);
  }
  form { display: flex; flex-direction: column; gap: 12px; }
  input {
    padding: 10px 12px;
    border: 1px solid var(--divider);
    border-radius: var(--radius-ctrl);
    font: 500 15px/1.4 var(--font-sans);
    color: var(--ink);
    background: var(--panel);
  }
  input:focus {
    outline: 2px solid var(--brand);
    outline-offset: -1px;
    border-color: var(--brand);
  }
  input::placeholder {
    color: var(--ink-faint);
  }
  button[type="submit"] {
    padding: 12px 14px;
    background: var(--ink);
    color: var(--panel);
    border: none;
    border-radius: var(--radius-ctrl);
    cursor: pointer;
    font: 700 15px/1.3 var(--font-sans);
  }
  button[type="submit"]:hover:not(:disabled) {
    opacity: 0.92;
  }
  button[type="submit"]:disabled { opacity: 0.5; }
  .error {
    color: #b91c1c;
    font: 500 13px/1.3 var(--font-sans);
    margin: 0;
  }
  .switch {
    margin-top: 12px;
    font: 500 13px/1.3 var(--font-sans);
    color: var(--ink-muted);
    text-align: center;
  }
  .link {
    background: none;
    border: none;
    color: var(--brand);
    cursor: pointer;
    text-decoration: underline;
    font: 600 13px/1.3 var(--font-sans);
    padding: 0;
  }

  @media (max-width: 640px) {
    .modal {
      padding: 24px 20px;
    }
  }
</style>
