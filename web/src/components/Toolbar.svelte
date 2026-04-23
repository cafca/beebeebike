<script>
  import { brush, ratingTools, undo, redo, syncBrushSizePreview, togglePaintMode } from '../lib/brush.svelte.js';
  import PaintRollerIcon from '../lib/PaintRollerIcon.svelte';

  let showSizePreview = $state(false);
  let hidePreviewTimer;

  let previewColor = $derived(
    ratingTools.find(r => r.value === brush.value)?.color ?? '#22c55e'
  );
  let previewDiameter = $derived(Number(brush.size) * 2);

  function showPreview() {
    clearTimeout(hidePreviewTimer);
    showSizePreview = true;
  }

  function hidePreviewSoon() {
    clearTimeout(hidePreviewTimer);
    hidePreviewTimer = setTimeout(() => showSizePreview = false, 700);
  }

  function handleBrushSizeInput() {
    showPreview();
    syncBrushSizePreview();
  }
</script>

<div class="toolbar">
  <div class="instructions">
    Hold command/control and drag to paint,<br>or use the paint mode toggle.
  </div>

  <button
    class="paint-toggle"
    class:active={brush.paintMode}
    onclick={togglePaintMode}
    title={brush.paintMode ? 'Exit paint mode' : 'Enter paint mode (draw with touch/click)'}
    aria-pressed={brush.paintMode}
  >
    <PaintRollerIcon size={24} />
  </button>

  <div class="color-strip">
    {#each ratingTools as r, i}
      <button
        class="color-btn"
        class:active={brush.value === r.value}
        style="background: {r.color}"
        onclick={() => brush.value = r.value}
        title={`${i + 1}: ${r.value === 0 ? 'Eraser' : r.value}`}
      >
        <span>{i + 1}</span>
      </button>
    {/each}
  </div>

  <div class="brush-controls">
    {#if showSizePreview}
      <div class="brush-size-preview" aria-hidden="true">
        <div
          class="brush-size-ring"
          style="width: {previewDiameter}px; height: {previewDiameter}px; border-color: {previewColor};"
        ></div>
      </div>
    {/if}
    <input
      type="range"
      min="5"
      max="80"
      bind:value={brush.size}
      oninput={handleBrushSizeInput}
      onpointerdown={showPreview}
      onpointerup={hidePreviewSoon}
      onpointercancel={hidePreviewSoon}
      onfocus={showPreview}
      onblur={() => showSizePreview = false}
      title="Brush size"
    />
  </div>

  <div class="undo-redo-inline">
    <button disabled={!brush.canUndo} onclick={undo} title="Undo (Ctrl+Z)">
      <svg viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
        <path d="M3 7h10a5 5 0 0 1 0 10H8"/><path d="M7 3l-4 4 4 4"/>
      </svg>
    </button>
    <button disabled={!brush.canRedo} onclick={redo} title="Redo (Ctrl+Shift+Z)">
      <svg viewBox="0 0 24 24" width="16" height="16" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
        <path d="M21 7H11a5 5 0 0 0 0 10h5"/><path d="M17 3l4 4-4 4"/>
      </svg>
    </button>
  </div>
</div>

<div class="undo-redo-fab">
  <button disabled={!brush.canUndo} onclick={undo} title="Undo (Ctrl+Z)">
    <svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
      <path d="M3 7h10a5 5 0 0 1 0 10H8"/><path d="M7 3l-4 4 4 4"/>
    </svg>
  </button>
  <button disabled={!brush.canRedo} onclick={redo} title="Redo (Ctrl+Shift+Z)">
    <svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" fill="none">
      <path d="M21 7H11a5 5 0 0 0 0 10h5"/><path d="M17 3l4 4-4 4"/>
    </svg>
  </button>
</div>

<style>
  .toolbar {
    position: absolute;
    bottom: 24px;
    left: 24px;
    right: 24px;
    margin: 0 auto;
    width: fit-content;
    background: var(--panel);
    border: 1px solid var(--divider);
    padding: 10px 12px;
    border-radius: var(--radius-ctrl);
    box-shadow: var(--shadow-sm);
    z-index: 10;
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .instructions {
    color: var(--ink-muted);
    font: 500 13px/1.3 var(--font-sans);
    min-width: 0;
    flex-shrink: 0;
  }
  .color-strip {
    display: flex;
    flex-shrink: 0;
  }
  .color-btn {
    position: relative;
    width: 34px;
    height: 34px;
    border: 2px solid transparent;
    cursor: pointer;
    transition: transform 0.1s;
  }
  .color-btn span {
    position: absolute;
    right: 3px;
    bottom: 2px;
    color: white;
    font: 700 10px/1 var(--font-mono);
    text-shadow: 0 1px 2px rgba(0, 0, 0, 0.5);
  }
  .color-btn:first-child { border-radius: 6px 0 0 6px; }
  .color-btn:last-child { border-radius: 0 6px 6px 0; }
  .color-btn.active {
    transform: scale(1.15);
    border-color: var(--panel);
    box-shadow: 0 0 0 2px var(--ink);
    z-index: 1;
  }
  .brush-controls {
    position: relative;
    flex-shrink: 0;
  }
  .brush-size-preview {
    position: absolute;
    bottom: calc(100% + 16px);
    left: 50%;
    width: 168px;
    height: 168px;
    transform: translateX(-50%);
    pointer-events: none;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .brush-size-ring {
    border: 2px solid;
    border-radius: 50%;
    background: rgba(255, 255, 255, 0.08);
    box-shadow: 0 0 0 4px rgba(255, 255, 255, 0.92), 0 2px 10px rgba(0, 0, 0, 0.22);
  }
  .brush-controls input {
    width: 80px;
    accent-color: var(--brand);
  }
  .undo-redo-inline {
    display: flex;
    gap: 4px;
  }
  .undo-redo-inline button {
    width: 32px;
    height: 32px;
    border: 1px solid var(--divider);
    border-radius: 8px;
    background: var(--panel);
    color: var(--ink-muted);
    cursor: pointer;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  .undo-redo-inline button:hover:not(:disabled) {
    color: var(--ink);
    background: var(--bg);
  }
  .undo-redo-inline button:disabled {
    opacity: 0.3;
    cursor: default;
    color: var(--ink-faint);
  }
  .undo-redo-fab {
    display: none;
  }
  .paint-toggle {
    width: 44px;
    height: 44px;
    border: 1px solid var(--divider);
    border-radius: var(--radius-ctrl);
    background: var(--panel);
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--ink);
    flex-shrink: 0;
    box-shadow: var(--shadow-sm);
    transition: background 0.05s, border-color 0.05s, box-shadow 0.05s;
  }
  .paint-toggle.active {
    background: var(--brand-soft);
    border-color: var(--brand);
    box-shadow: 0 0 0 2px var(--brand-soft), var(--shadow-sm);
  }

  @media (max-width: 800px) {
    .instructions {
      display: none;
    }
  }

  @media (max-width: 640px) {
    .toolbar {
      padding: 6px;
      gap: 6px;
      bottom: 12px;
      max-width: calc(100vw - 16px);
    }
    .color-btn {
      width: 40px;
      height: 40px;
    }
    .color-btn span {
      display: none;
    }
    .paint-toggle {
      width: 40px;
      height: 40px;
      border: 1px solid var(--divider);
      border-radius: var(--radius-ctrl);
    }
    .color-btn:first-child {
      border-radius: 0;
    }
    .brush-controls {
      display: none;
    }
    .undo-redo-inline {
      display: none;
    }
    .undo-redo-fab {
      display: flex;
      flex-direction: column;
      gap: 8px;
      position: fixed;
      bottom: 80px;
      right: 12px;
      z-index: 10;
    }
    .undo-redo-fab button {
      width: 48px;
      height: 48px;
      border: 1px solid var(--divider);
      border-radius: var(--radius-fab);
      background: var(--panel);
      color: var(--ink);
      box-shadow: var(--shadow-sm);
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      justify-content: center;
    }
    .undo-redo-fab button:disabled {
      opacity: 0.3;
      cursor: default;
      color: var(--ink-faint);
    }
  }
</style>
