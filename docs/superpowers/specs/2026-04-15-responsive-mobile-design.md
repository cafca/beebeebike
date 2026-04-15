# Responsive Design & Mobile Touch Interactions

## Goal

Make the beebeebike frontend fully usable on mobile devices with touch interactions, while preserving the existing desktop UX (Cmd/Ctrl + drag to paint).

## 1. Paint Mode Toggle

Add a `paintModeActive` boolean to `brush.svelte.js` shared state.

- The paint check becomes: `isPaintModifier(e) || paintModeActive`
- A toggle button in the toolbar activates/deactivates paint mode
- Available on all screen sizes (optional convenience on desktop, primary input on mobile)
- When active: single-touch/click drags paint, `dragPan` is disabled (same as current Cmd+drag behavior)
- When active: two-finger gestures still pan/zoom (MapLibre handles this — only `dragPan` is disabled, not `touchZoomRotate`)
- Desktop Cmd/Ctrl modifier continues to work regardless of toggle state

## 2. Pointer Events for Touch

Replace mouse events with pointer events in `brush.svelte.js`:

- `mousedown` → `pointerdown`
- `mousemove` → `pointermove`
- `mouseup` → `pointerup`
- `mouseleave` → `pointerleave`

Pointer events fire for both mouse and touch — desktop behavior is unchanged.

When paint mode is active, set `touch-action: none` on the map canvas to prevent browser scroll/zoom from competing with the paint gesture. Remove it when paint mode is deactivated.

## 3. Responsive Layout

Breakpoint: `640px` (standard mobile threshold).

### Search bar (`SearchBar.svelte`)

- Change `width: 340px` to `width: min(340px, calc(100vw - 24px))`

### Route panel (`RoutePanel.svelte`)

- On narrow screens: position below the search bar instead of `left: 360px`
- Use `top: auto` stacking under the search container, or switch to a flow layout within a shared top-left container

### User bar (`App.svelte`)

- On narrow screens: reduce padding, shrink font, move closer to edge
- Consider hiding "Guest" label and just showing action buttons

### Toolbar (`Toolbar.svelte`)

- Hide instruction text below 640px (references Cmd/Ctrl, irrelevant on mobile)
- Add paint-mode toggle button (visible at all sizes)
- Increase touch targets to minimum 44px on mobile
- Keep color strip, brush size slider, undo/redo in a compact row
- The toolbar already has `max-width: min(720px, calc(100vw - 24px))` and wraps — extend the existing `@media` rule

### Auth modal (`AuthModal.svelte`)

- Change `min-width: 320px` to `min-width: min(320px, calc(100vw - 32px))` so it doesn't overflow on very narrow screens

## 4. Mobile-specific instruction text

When paint mode toggle is visible and instructions are hidden (mobile), the toggle button itself should be self-explanatory — use a brush/pencil icon with active state styling (filled vs outlined, or color change).

On desktop, update instruction text to mention the toggle as an alternative: "Hold Cmd/Ctrl and drag to paint, or toggle paint mode."

## Files to modify

- `frontend/src/lib/brush.svelte.js` — paint mode state, pointer events, touch-action management
- `frontend/src/components/Toolbar.svelte` — toggle button, responsive layout, touch targets
- `frontend/src/components/SearchBar.svelte` — responsive width
- `frontend/src/components/RoutePanel.svelte` — responsive positioning
- `frontend/src/components/AuthModal.svelte` — responsive min-width
- `frontend/src/App.svelte` — user bar responsive styles

## Out of scope

- Changing the rating values or brush mechanics
- Backend changes
- New components or pages
