# Route Markers Design

**Date:** 2026-04-15

## Goal

Show a map pin at the origin and destination when they are set, using colors that are harmonious with the existing red/teal rating palette.

## Colors

Both colors are from the Flat UI Colors family, matching the visual weight of the existing palette (`#e74c3c`, `#1abc9c`):

| Role | Color | Hex |
|------|-------|-----|
| Origin (start) | Sunflower | `#f1c40f` |
| Destination | Belize Hole | `#2980b9` |

## Changes

### `frontend/src/lib/routing.svelte.js`

- Add two module-level marker variables: `originMarker`, `destMarker`.
- Add `syncRouteMarkers()` (exported):
  - If `route.origin` is set and `route.origin.savedLocationName !== 'home'`, create/update `originMarker` at the origin coordinates using a yellow (`#f1c40f`) pin SVG.
  - If `route.destination` is set, create/update `destMarker` using a blue (`#2980b9`) pin SVG.
  - Remove markers whose corresponding route point is null.
- Pin SVG: same teardrop shape as `createHomeMarkerElement()`, filled with the role color, small white circle inside instead of the house icon. `anchor: 'bottom'`.
- Call `syncRouteMarkers()` at the end of `clearRoute()` so markers are removed immediately on clear.

### `frontend/src/App.svelte`

- Add one `$effect` that reads `route.origin` and `route.destination` and calls `syncRouteMarkers()`.
- Import `syncRouteMarkers` from `routing.svelte.js`.

### `frontend/src/components/SearchBar.svelte`

- Update `.origin-dot` background from `#1abc9c` → `#f1c40f`.
- Update `.dest-dot` background from `#e74c3c` → `#2980b9`.

## Edge cases

- **Origin is home location:** `syncRouteMarkers()` checks `route.origin.savedLocationName === 'home'` and skips the origin marker. The existing home marker covers this case.
- **Partial route (origin set, destination not yet):** Only the origin marker shows.
- **Route cleared:** `clearRoute()` calls `syncRouteMarkers()` directly, removing both markers immediately without waiting for the reactive effect.
- **Map not initialized:** `syncRouteMarkers()` is a no-op if `currentMap` is null.
