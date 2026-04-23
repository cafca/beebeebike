# iOS brush drawing — design

Port the web painting feature (rated-area polygons) to the Flutter/iOS app, matching the web's mobile-responsive (@640px) layout.

## Goals

- User can paint rated areas on the iOS map with finger-drag, picking rating from a 7-color palette.
- Eraser (value 0) removes overlapping areas.
- Single-tap on an existing rated polygon recolors (or deletes with eraser).
- Undo / redo available as floating action buttons.
- Geometry, API contract, colors, and clipping behavior match the web exactly.

Non-goals:

- Brush-size adjustment (fixed 30px, zoom-scaled).
- Keyboard shortcuts.
- Brush cursor ring during stroke (touch finger occludes anyway).
- Android (iOS only per v0.1 platform scope).

## UX

### Paint mode

- Entry: a "Paint my ratings" action inside HomeSheet flips `paintMode = true` with default value 1 → PaintSheet slides up.
- In paint mode the PaintSheet holds the paint-toggle (acts as exit) and the 7 color chips. Tapping any color chip selects that rating and keeps paint mode on. Tapping the paint-toggle exits paint mode and reverts to the previously active sheet.
- While `paintMode`: single-finger drag = paint. Pinch-zoom still works. Pan/rotate/tilt disabled on the map.
- Out of paint mode: map behaves as today (route-preview on tap, native pan/zoom).

### Rating values + colors (identical to web)

| Value | Hex       | Role           |
|-------|-----------|----------------|
| -7    | `#c0392b` | very bad       |
| -3    | `#e74c3c` | bad            |
| -1    | `#f1948a` | slightly bad   |
| 0     | `#6b7280` | eraser         |
| 1     | `#76d7c4` | slightly good  |
| 3     | `#1abc9c` | good           |
| 7     | `#0e6655` | very good      |

### Layout — fits the three-sheet stack pattern

The browse overlay already renders one of HomeSheet / RouteSheet / NavigationSheet via an `AnimatedSwitcher`, with the my-location FAB floating above the active sheet's top edge. The paint UI extends this pattern rather than overlaying it.

- **PaintSheet** — new fourth sibling in the `AnimatedSwitcher`. Fixed height (~96px). Content: drag handle + paint-toggle button (functions as exit) + horizontal row of 7 color chips (40px, no number labels, selected chip highlighted via ring + scale). No brush-size slider. No inline undo/redo. Styled consistently with the other sheets (white, rounded top corners, elevation, safe-area inset).
- **Undo/redo FABs** — bottom-right, stacked vertical column, 48px circles, 8px gap. Positioned above the existing my-location FAB using the same sheet-size tracking offset so they rise with the active sheet. Visible only while `paintMode == true`. Disabled when `canUndo` / `canRedo` is false.
- **Sheet priority** (highest wins):
  1. `navActive` → NavigationSheet (paint mode forced off on entry)
  2. `paintMode` → PaintSheet
  3. `routeActive` → RouteSheet
  4. default → HomeSheet
- All paint chrome (PaintSheet + undo/redo FABs) is hidden whenever `navActive`.

### Stroke feedback

- Live preview polygon: semi-transparent fill (0.3 opacity) in the current rating's color, updated as the finger drags past each sample threshold. Cleared on commit/cancel.
- No finger/cursor ring (industry standard on touch paint apps).
- On API error: preview cleared, stroke discarded, error logged. No retry UI.

### Single-tap recolor

If a stroke yields <2 sampled points (essentially a tap), query rendered features at the tap pixel against the rating fill layer. If a feature is hit, submit a paint request with that polygon's geometry + current value + `target_id` = feature's area id. Eraser taps delete the hit polygon.

## Architecture

Mirrors the existing `RatingOverlay` pattern: pure-Dart core + MapLibre adapter + Riverpod controller + UI widgets + API client.

### New files

- `mobile/lib/providers/brush_provider.dart`
  `BrushController` (`NotifierProvider`). State: `value:int` (default 1), `paintMode:bool`, `canUndo:bool`, `canRedo:bool`, `strokePoints:List<LatLng>`. Methods:
  - `setValue(int v)` — sets value, flips `paintMode = true`.
  - `togglePaintMode()` — off clears any in-flight stroke.
  - `startStroke(LatLng first)` / `addPoint(LatLng, double zoom)` / `endStroke()` — `endStroke` decides tap-recolor vs polygon-commit path.
  - `tapRecolor(LatLng, int areaId)` — internal, called from endStroke fallback.
  - `undo()` / `redo()` — call API, update flags, trigger overlay refresh.

- `mobile/lib/services/brush_overlay.dart`
  MapLibre adapter. Adds one GeoJSON source (`brush-preview`) + one `FillLayer` above the rating overlay. Methods: `attach(MapLibreMapController)`, `setPreview(Map geometry, String colorHex)`, `clear()`, `detach()`.

- `mobile/lib/services/brush_geometry.dart`
  Pure Dart. Depends on `turf` pkg for `buffer()`. Helpers:
  - `double metersPerPixel(double lat, double zoom)` — `40075016.686 * cos(lat·π/180) / 2^(zoom+9)`.
  - `Map<String, dynamic>? buildPolygon(List<LatLng> pts, double zoom, {double brushPx = 30})` — returns GeoJSON Polygon `geometry`, or null when <2 points. Radius km = `max(brushPx * mpp / 1000, 0.005)`.
  - `bool shouldSample(Point<double> last, Point<double> next)` — true if squared pixel distance ≥ 16 (i.e. `MIN_MOVE_PX = 4`). Screen-pixel conversion via `mapController.toScreenLocation(latLng)`.

- `mobile/lib/api/ratings_paint_api.dart`
  - `Future<PaintResponse> paint({required Map geometry, required int value, int? targetId})` → `PUT /api/ratings/paint`.
  - `Future<PaintResponse> undo()` → `POST /api/ratings/undo`.
  - `Future<PaintResponse> redo()` → `POST /api/ratings/redo`.

  `PaintResponse` (freezed): `createdId`, `clippedCount`, `deletedCount`, `canUndo`, `canRedo`.

- `mobile/lib/widgets/paint_sheet.dart`
  Sheet widget with the same visual treatment as `RouteSheet` (white container, rounded top, SafeArea bottom, drag handle). Content: paint-toggle button (exit) + horizontal row of 7 color chips. Watches `brushProvider`. Inserted as a fourth sibling in the existing `AnimatedSwitcher` in `map_screen.dart`.

- `mobile/lib/widgets/undo_redo_fabs.dart`
  Bottom-right vertical column of two 48px FABs (undo, redo). Watches `canUndo`/`canRedo` from `brushProvider`. Visible only when `paintMode == true` (and `navActive == false`). Tracks the active sheet's top edge the same way the my-location FAB does so the stack rises with the sheet.

- Entry point: a "Paint my ratings" action inside `HomeSheet` (added to the existing content in `map_screen.dart`'s `HomeSheet` builder). Tapping it sets `paintMode = true` with default `value = 1`, causing the `AnimatedSwitcher` to surface the PaintSheet.

### Modified files

- `mobile/lib/screens/map_screen.dart`
  - Wrap `MapLibreMap` in a conditional `GestureDetector` (active only when `brushProvider.paintMode`), wiring `onPanStart/Update/End` to the controller. Convert `details.localPosition` → `LatLng` via `_mapController.toLatLng(Point(dx, dy))`.
  - Toggle `scrollGesturesEnabled`, `rotateGesturesEnabled`, `tiltGesturesEnabled` based on paint mode; keep `zoomGesturesEnabled = true`.
  - `onStyleLoadedCallback` also calls `brushOverlay.attach(_mapController)` after rating overlay attaches, ensuring brush preview renders above rating fill.
  - Add `PaintSheet` as a fourth branch inside the existing browse-overlay `AnimatedSwitcher`, applying the sheet priority order (nav > paint > route > home).
  - Add `UndoRedoFabs` widget to the stack, following the same sheet-tracked bottom-offset pattern as the my-location FAB.
  - When `navActive` flips to true, force `paintMode = false` to close any open PaintSheet.
  - Add a "Paint my ratings" tap target inside `HomeSheet` content that enters paint mode.

- `mobile/pubspec.yaml` — add `turf` dependency.

### Data flow

1. Color chip tapped → `setValue(n)` → `value=n`, `paintMode=true`.
2. `onPanStart` → `startStroke(latLng)`. Preview cleared.
3. `onPanUpdate` → screen-distance check via `shouldSample`. Qualifying sample → `addPoint(latLng, zoom)`. Controller rebuilds polygon via `brushGeometry.buildPolygon` and calls `brushOverlay.setPreview(geom, color)`.
4. `onPanEnd` → `endStroke()`:
   - If `strokePoints.length < 2`: `queryRenderedFeatures(point, layerIds: [ratingFillLayerId])`. If hit → `ratingsPaintApi.paint(geometry: feature.geometry, value, targetId: feature.areaId)`. Otherwise: no-op.
   - Else: `ratingsPaintApi.paint(geometry: buildPolygon(strokePoints, zoom), value, targetId: null)`.
5. On response: update `canUndo`/`canRedo`, call `ratingOverlayController.refresh()`, clear preview.
6. On error: clear preview, keep state, log.
7. Undo/redo FABs call `ratingsPaintApi.undo()/redo()`, same overlay-refresh + flag-update pattern.

### Gesture arena

MapLibre's `EagerGestureRecognizer` wins single-pointer gestures by default. In paint mode the map's own scroll/rotate/tilt flags are disabled, so MapLibre declines the pointer and the outer `GestureDetector` picks it up. Pinch (two-pointer) still routes to MapLibre because `zoomGesturesEnabled` remains true — and our `GestureDetector` only handles single-pointer pan.

### Overlay sync

- After every successful `paint/undo/redo`, invoke `RatingOverlayController.refresh()` to re-fetch the current bbox.
- SSE push invalidations from `rating_events_client.dart` continue to handle cross-session updates; no change needed.

## API contract (unchanged from web)

**`PUT /api/ratings/paint`**

Request:
```json
{
  "geometry": { "type": "Polygon", "coordinates": [[[lng, lat], ...]] },
  "value": -7 | -3 | -1 | 0 | 1 | 3 | 7,
  "target_id": <int> | null
}
```

Response:
```json
{
  "created_id": <int> | null,
  "clipped_count": <int>,
  "deleted_count": <int>,
  "can_undo": <bool>,
  "can_redo": <bool>
}
```

**`POST /api/ratings/undo`**, **`POST /api/ratings/redo`** — no body, same response shape.

Coordinate order `[lng, lat]`. Ring must be closed (first == last). Backend handles `ST_MakeValid` / clipping / eraser semantics.

## Testing

- `test/brush_geometry_test.dart` — `metersPerPixel` at known lat/zoom, `buildPolygon` returns closed polygon with positive area and vertex count ≥ 8 for a 3-point stroke, returns null for <2 points, applies minimum 5m radius.
- `test/brush_controller_test.dart` — `setValue` auto-enables paintMode, `togglePaintMode` off clears stroke, `endStroke` with <2 points triggers tap-recolor path, API error path clears preview, response flags update `canUndo/canRedo`.
- `integration_test/brush_test.dart` — enter paint mode by tapping color chip, simulate pan drag across map, assert `PUT /api/ratings/paint` called with Polygon geometry and correct value. Requires stubbed API.

## Risks / open questions

- **`turf` pub package maturity** — if `buffer()` behaves inconsistently with Turf.js on edge cases (very small radii, extreme latitudes), fallback is hand-rolling perpendicular offset + end caps (~80 LOC). Decide after first spike.
- **`mapController.toLatLng`** precision — MapLibre's screen→world conversion may be noisy at low zoom. Acceptable because polygons get smoothed by buffer anyway.
- **`queryRenderedFeatures` layer id** — must match the rating fill layer id declared in `rating_overlay.dart`. Plan ensures this is exposed as a constant.
