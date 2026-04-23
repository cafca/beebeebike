<script>
  let { map } = $props();
</script>

<div class="zoom-controls">
  <button onclick={() => map?.zoomIn()} aria-label="Zoom in">
    <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" fill="none">
      <path d="M12 5v14M5 12h14"/>
    </svg>
  </button>
  <button onclick={() => map?.zoomOut()} aria-label="Zoom out">
    <svg viewBox="0 0 24 24" width="18" height="18" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" fill="none">
      <path d="M5 12h14"/>
    </svg>
  </button>
</div>

<style>
  .zoom-controls {
    position: fixed;
    bottom: 48px;
    right: 16px;
    z-index: 10;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }
  button {
    width: 40px;
    height: 40px;
    border-radius: var(--radius-fab);
    border: 1px solid var(--divider);
    background: var(--panel);
    box-shadow: var(--shadow-sm);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--ink);
  }
  button:hover { background: var(--bg); }
  button:active { background: var(--bg-alt); }

  @media (max-width: 640px) {
    .zoom-controls {
      /* undo/redo FABs occupy bottom: 80px, 2×48px + 8px gap = 104px → top at 184px */
      bottom: 200px;
      right: 12px;
    }
    button {
      width: 48px;
      height: 48px;
    }
  }
</style>
