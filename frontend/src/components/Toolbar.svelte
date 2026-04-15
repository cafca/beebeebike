<script>
  import { brush, ratingTools, undo, redo } from '../lib/brush.svelte.js';
</script>

<div class="toolbar">
  <div class="instructions">
    Drag while holding command / control to paint where you like or dislike biking.
  </div>

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
    padding: 10px 12px;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.2);
    z-index: 10;
    display: flex;
    gap: 12px;
    align-items: center;
    max-width: min(720px, calc(100vw - 24px));
  }
  .instructions {
    max-width: 240px;
    color: #374151;
    font-size: 13px;
    line-height: 1.25;
  }
  .color-strip {
    display: flex;
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
    font-size: 10px;
    font-weight: 700;
    line-height: 1;
    text-shadow: 0 1px 2px rgba(0,0,0,0.5);
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

  @media (max-width: 620px) {
    .toolbar {
      flex-wrap: wrap;
      justify-content: center;
    }
    .instructions {
      max-width: 100%;
      text-align: center;
    }
  }
</style>
