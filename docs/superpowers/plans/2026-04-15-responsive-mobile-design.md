# Responsive Design & Mobile Touch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app fully usable on mobile with touch-based painting and responsive layout.

**Architecture:** Add a paint-mode toggle to brush state, replace mouse events with pointer events, and add responsive CSS breakpoints at 640px across all UI components.

**Tech Stack:** Svelte 5 (runes), MapLibre GL JS, CSS media queries

**No test framework exists** — verification is manual browser testing (dev server + browser DevTools device emulation).

---

### Task 1: Paint mode toggle state + pointer events in brush.svelte.js

**Files:**
- Modify: `frontend/src/lib/brush.svelte.js`

- [ ] **Step 1: Add `paintModeActive` to shared state and `togglePaintMode` export**

Add to the existing `brush` state object:

```js
export const brush = $state({
  value: 1,
  size: 30,
  canUndo: false,
  canRedo: false,
  paintMode: false,
});
```

Add a toggle function that also manages `dragPan` and `touch-action`:

```js
export function togglePaintMode() {
  brush.paintMode = !brush.paintMode;
  if (currentMap) {
    if (brush.paintMode) {
      currentMap.dragPan.disable();
      currentMap.getCanvas().style.touchAction = 'none';
    } else {
      currentMap.dragPan.enable();
      currentMap.getCanvas().style.touchAction = '';
    }
  }
  syncCursor();
}
```

- [ ] **Step 2: Update `isPaintModifier` to include paint mode**

```js
function isPaintModifier(e) {
  return e.metaKey || e.ctrlKey || brush.paintMode;
}
```

- [ ] **Step 3: Replace mouse events with pointer events**

In `initBrush`, replace all event registrations:

```js
currentCanvas.addEventListener('pointerdown', onPointerDown, listenerOptions);
currentCanvas.addEventListener('pointermove', onPointerMove, listenerOptions);
currentCanvas.addEventListener('pointerleave', onPointerLeave, listenerOptions);
document.addEventListener('pointerup', onPointerUp, listenerOptions);
```

Remove old mouse event listeners. Rename handlers:
- `onMouseDown` → `onPointerDown`
- `onMouseMove` → `onPointerMove`
- `onMouseUp` → `onPointerUp`
- `onMouseLeave` → `onPointerLeave`

In `onPointerDown`, change `e.offsetX`/`e.offsetY` usage — these work the same on PointerEvent. Remove `if (e.button !== 0) return;` check and replace with `if (e.button !== 0 && e.button !== undefined) return;` to allow touch (which has no button).

Actually, touch pointerdown has `button === 0`, so keep `if (e.button !== 0) return;` as-is.

In `onPointerDown`, when paint mode is active, we need to handle the case where dragPan is already disabled (don't re-disable/re-enable):

```js
function onPointerDown(e) {
  if (!isPaintModifier(e)) return;
  if (e.button !== 0) return;
  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();

  painting = true;
  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);
  points = [lastCursorLngLat];
  if (!brush.paintMode) {
    dragPanWasEnabled = currentMap.dragPan.isEnabled();
    if (dragPanWasEnabled) currentMap.dragPan.disable();
  }
  syncCursor();
  updateBrushCursor(lastCursorLngLat);
}
```

Update `restoreDragPan` to not re-enable when paint mode is active:

```js
function restoreDragPan() {
  if (brush.paintMode) return;
  if (currentMap && dragPanWasEnabled && !currentMap.dragPan.isEnabled()) {
    currentMap.dragPan.enable();
  }
  dragPanWasEnabled = false;
}
```

- [ ] **Step 4: Update `destroyBrush` to clean up pointer events and paint mode**

```js
export function destroyBrush() {
  if (currentCanvas) {
    currentCanvas.style.cursor = '';
    currentCanvas.style.touchAction = '';
    currentCanvas.removeEventListener('pointerdown', onPointerDown, listenerOptions);
    currentCanvas.removeEventListener('pointermove', onPointerMove, listenerOptions);
    currentCanvas.removeEventListener('pointerleave', onPointerLeave, listenerOptions);
  }
  document.removeEventListener('pointerup', onPointerUp, listenerOptions);
  document.removeEventListener('keydown', onKeyDown);
  document.removeEventListener('keyup', onKeyUp);
  if (brush.paintMode && currentMap) {
    currentMap.dragPan.enable();
  }
  brush.paintMode = false;
  painting = false;
  points = [];
  modifierDown = false;
  lastCursorLngLat = null;
  clearBrushCursor();
  restoreDragPan();
  initialized = false;
  currentCanvas = null;
  currentMap = null;
}
```

- [ ] **Step 5: Update cursor logic for paint mode**

Update `syncCursor` to show crosshair when paint mode is active:

```js
function syncCursor() {
  if (!currentMap) return;
  const canvas = currentMap.getCanvas();
  canvas.style.cursor = painting || modifierDown || brush.paintMode ? 'crosshair' : '';
}
```

Update `onPointerMove` to show brush cursor when paint mode is active (even without modifier):

```js
function onPointerMove(e) {
  lastCursorLngLat = currentMap.unproject([e.offsetX, e.offsetY]);

  if (!painting) {
    const paintModifier = isPaintModifier(e);
    modifierDown = paintModifier;
    syncCursor();

    if (paintModifier) {
      updateBrushCursor(lastCursorLngLat);
    } else {
      clearBrushCursor();
    }
    return;
  }

  e.preventDefault();
  e.stopPropagation();
  e.stopImmediatePropagation?.();
  points.push(lastCursorLngLat);
  updateBrushCursor(lastCursorLngLat);
  updatePreview();
}
```

(This works because `isPaintModifier` now returns true when `brush.paintMode` is true.)

- [ ] **Step 6: Commit**

```bash
git add frontend/src/lib/brush.svelte.js
git commit -m "Add paint mode toggle and replace mouse events with pointer events"
```

---

### Task 2: Paint mode toggle button in Toolbar

**Files:**
- Modify: `frontend/src/components/Toolbar.svelte`

- [ ] **Step 1: Import `togglePaintMode` and add toggle button**

Update the import:

```js
import { brush, ratingTools, undo, redo, syncBrushSizePreview, togglePaintMode } from '../lib/brush.svelte.js';
```

Add the toggle button before the color strip in the template:

```svelte
<button
  class="paint-toggle"
  class:active={brush.paintMode}
  onclick={togglePaintMode}
  title={brush.paintMode ? 'Exit paint mode' : 'Enter paint mode (draw with touch/click)'}
>
  <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M12 19l7-7 3 3-7 7-3-3z"/>
    <path d="M18 13l-1.5-7.5L2 2l3.5 14.5L13 18l5-5z"/>
    <path d="M2 2l7.586 7.586"/>
    <circle cx="11" cy="11" r="2"/>
  </svg>
</button>
```

- [ ] **Step 2: Update instruction text to mention toggle on desktop, hide on mobile**

```svelte
<div class="instructions">
  Hold command/control and drag to paint, or use the paint mode toggle.
</div>
```

- [ ] **Step 3: Add styles for the toggle button and update responsive breakpoint**

```css
.paint-toggle {
  width: 40px;
  height: 40px;
  border: 2px solid #ddd;
  border-radius: 8px;
  background: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #374151;
  flex-shrink: 0;
  transition: background 0.15s, border-color 0.15s;
}
.paint-toggle.active {
  background: #2563eb;
  border-color: #2563eb;
  color: white;
}
```

Update the mobile media query to hide instructions and increase touch targets:

```css
@media (max-width: 640px) {
  .toolbar {
    flex-wrap: wrap;
    justify-content: center;
    padding: 8px;
    gap: 8px;
    bottom: 12px;
  }
  .instructions {
    display: none;
  }
  .color-btn {
    width: 44px;
    height: 44px;
  }
  .paint-toggle {
    width: 44px;
    height: 44px;
  }
  .undo-redo button {
    width: 44px;
    height: 44px;
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/components/Toolbar.svelte
git commit -m "Add paint mode toggle button with responsive toolbar layout"
```

---

### Task 3: Responsive SearchBar and RoutePanel

**Files:**
- Modify: `frontend/src/components/SearchBar.svelte`
- Modify: `frontend/src/components/RoutePanel.svelte`

- [ ] **Step 1: Make SearchBar width responsive**

In `SearchBar.svelte`, change the `.search-container` style:

```css
.search-container {
  position: absolute; top: 12px; left: 12px; z-index: 10;
  width: min(340px, calc(100vw - 24px));
}
```

Also increase touch target for result items on mobile:

```css
@media (max-width: 640px) {
  .result-btn {
    padding: 14px 12px;
  }
}
```

- [ ] **Step 2: Make RoutePanel position responsive**

In `RoutePanel.svelte`, replace the fixed positioning with responsive styles:

```css
.route-panel {
  position: absolute; top: 12px; left: 360px;
  background: white; padding: 10px 16px; border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 10;
  font-size: 14px; display: flex; gap: 4px;
}

@media (max-width: 640px) {
  .route-panel {
    left: 12px;
    top: auto;
    top: 80px;
  }
}
```

The `top: 80px` places it below the search bar on mobile. The search bar is ~50px tall + 12px top offset, so 80px gives a small gap.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/components/SearchBar.svelte frontend/src/components/RoutePanel.svelte
git commit -m "Make SearchBar and RoutePanel responsive on mobile"
```

---

### Task 4: Responsive user bar and auth modal

**Files:**
- Modify: `frontend/src/App.svelte`
- Modify: `frontend/src/components/AuthModal.svelte`

- [ ] **Step 1: Make user bar responsive**

In `App.svelte`, add a mobile media query:

```css
@media (max-width: 640px) {
  .user-bar {
    right: 12px;
    padding: 6px 10px;
    gap: 8px;
    font-size: 12px;
  }
}
```

- [ ] **Step 2: Make auth modal responsive**

In `AuthModal.svelte`, change `min-width` to be responsive:

```css
.modal {
  position: relative;
  background: white; padding: 32px; border-radius: 12px;
  min-width: min(320px, calc(100vw - 32px));
  box-shadow: 0 4px 24px rgba(0,0,0,0.2);
}
```

Add mobile padding reduction:

```css
@media (max-width: 640px) {
  .modal {
    padding: 24px 20px;
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/App.svelte frontend/src/components/AuthModal.svelte
git commit -m "Make user bar and auth modal responsive on mobile"
```

---

### Task 5: Manual browser testing

- [ ] **Step 1: Start dev server**

```bash
cd frontend && npm run dev
```

- [ ] **Step 2: Test desktop behavior**

Open in browser at full width:
- Verify Cmd/Ctrl + drag still paints
- Verify paint mode toggle button appears and works (click toggle, then drag to paint)
- Verify toggling paint mode off restores normal map panning
- Verify brush cursor, preview, undo/redo all work
- Verify search, routing, user bar all display correctly

- [ ] **Step 3: Test mobile behavior (DevTools device emulation)**

Open Chrome DevTools → Toggle device toolbar → Select a mobile device (e.g. iPhone 14):
- Verify toolbar is compact, instructions hidden, paint toggle visible
- Verify touch targets are large enough (44px)
- Verify search bar fills available width
- Verify route panel appears below search bar, not clipped off-screen
- Verify auth modal fits on screen
- Verify user bar is compact
- Activate paint mode → verify single-finger drag paints
- Deactivate paint mode → verify single-finger drag pans the map
- In paint mode → verify two-finger pinch still zooms

- [ ] **Step 4: Fix any issues found during testing**

- [ ] **Step 5: Final commit if any fixes were needed**
