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
    border-radius: 50%;
    border: 1px solid #ddd;
    background: white;
    box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #374151;
  }
  button:hover { background: #f3f4f6; }
  button:active { background: #e5e7eb; }

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
