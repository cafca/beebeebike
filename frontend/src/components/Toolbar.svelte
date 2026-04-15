<script>
  import { brush, setBrushActive, undo, redo } from '../lib/brush.svelte.js';

  const ratings = [
    { value: -7, color: '#991b1b' },
    { value: -3, color: '#dc2626' },
    { value: -1, color: '#fca5a5' },
    { value: 0,  color: '#6b7280' },  // eraser
    { value: 1,  color: '#86efac' },
    { value: 3,  color: '#22c55e' },
    { value: 7,  color: '#059669' },
  ];
</script>

<div class="toolbar">
  <div class="mode-toggle">
    <button
      class="mode-btn"
      class:active={!brush.active}
      onclick={() => setBrushActive(false)}
      title="Move map"
    >Move</button>
    <button
      class="mode-btn"
      class:active={brush.active}
      onclick={() => setBrushActive(true)}
      title="Paint ratings"
    >Paint</button>
  </div>

  <div class="color-strip">
    {#each ratings as r}
      <button
        class="color-btn"
        class:active={brush.value === r.value}
        class:disabled={!brush.active}
        style="background: {r.color}"
        onclick={() => {
          brush.value = r.value;
          setBrushActive(true);
        }}
        title={r.value === 0 ? 'Eraser' : String(r.value)}
      ></button>
    {/each}
  </div>

  <div class="brush-controls">
    <input
      type="range"
      min="5"
      max="80"
      bind:value={brush.size}
      title="Brush size"
    />
  </div>

  <div class="undo-redo">
    <button disabled={!brush.canUndo} onclick={undo} title="Undo (Ctrl+Z)">↩</button>
    <button disabled={!brush.canRedo} onclick={redo} title="Redo (Ctrl+Shift+Z)">↪</button>
  </div>
</div>

<style>
  .toolbar {
    position: absolute;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: white;
    padding: 8px 12px;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.2);
    z-index: 10;
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .color-strip {
    display: flex;
  }
  .mode-toggle {
    display: flex;
    gap: 4px;
  }
  .mode-btn {
    height: 32px;
    padding: 0 10px;
    border: 1px solid #d1d5db;
    border-radius: 6px;
    background: white;
    cursor: pointer;
  }
  .mode-btn.active {
    background: #2563eb;
    border-color: #2563eb;
    color: white;
  }
  .color-btn {
    width: 32px;
    height: 32px;
    border: 2px solid transparent;
    cursor: pointer;
    transition: transform 0.1s;
  }
  .color-btn.disabled {
    opacity: 0.55;
  }
  .color-btn:first-child { border-radius: 6px 0 0 6px; }
  .color-btn:last-child { border-radius: 0 6px 6px 0; }
  .color-btn.active {
    transform: scale(1.15);
    border-color: white;
    box-shadow: 0 0 0 2px #333;
    z-index: 1;
  }
  .brush-controls input {
    width: 80px;
  }
  .undo-redo {
    display: flex;
    gap: 4px;
  }
  .undo-redo button {
    width: 32px;
    height: 32px;
    border: 1px solid #ddd;
    border-radius: 6px;
    background: white;
    cursor: pointer;
    font-size: 16px;
  }
  .undo-redo button:disabled {
    opacity: 0.3;
    cursor: default;
  }
</style>
