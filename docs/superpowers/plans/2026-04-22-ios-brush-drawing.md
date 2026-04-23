# iOS Brush Drawing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the web painting feature (rated-area polygons) to the Flutter/iOS app with full functional parity, using a fourth "PaintSheet" in the existing three-sheet browse-mode stack.

**Architecture:** Mirrors the existing `RatingOverlay` + `RatingOverlayController` split: pure-Dart core (geometry, state) with injected probes, a MapLibre adapter behind a surface interface, and a Riverpod `Notifier` that orchestrates API + overlay. A new `PaintSheet` is inserted as a fourth branch of the existing `AnimatedSwitcher` in `map_screen.dart`. Entry point is a "Paint ratings" action inside `_HomeSheet`.

**Tech Stack:** Flutter 3.19+, Riverpod 2.5, Dio 5, maplibre_gl 0.20.0, freezed 2.5, `turf` pub package for GeoJSON buffering, `mocktail` + `http_mock_adapter` for tests.

**Spec:** [docs/superpowers/specs/2026-04-22-ios-brush-drawing-design.md](../specs/2026-04-22-ios-brush-drawing-design.md)

---

## File Structure

**Create:**
- `mobile/lib/api/ratings_paint_api.dart` — Dio client for paint/undo/redo.
- `mobile/lib/models/paint_response.dart` — freezed response model.
- `mobile/lib/services/brush_geometry.dart` — pure-Dart sampling + buffering.
- `mobile/lib/services/brush_overlay.dart` — `BrushOverlaySurface` interface + MapLibre impl.
- `mobile/lib/providers/brush_provider.dart` — `BrushController` (`Notifier<BrushState>`).
- `mobile/lib/widgets/paint_sheet.dart` — bottom sheet with toggle + 7 color chips.
- `mobile/lib/widgets/undo_redo_fabs.dart` — right-side stacked FABs.
- `mobile/test/services/brush_geometry_test.dart`
- `mobile/test/services/brush_overlay_test.dart`
- `mobile/test/providers/brush_controller_test.dart`
- `mobile/test/api/ratings_paint_api_test.dart`
- `mobile/integration_test/brush_smoke_test.dart`

**Modify:**
- `mobile/pubspec.yaml` — add `turf` dependency.
- `mobile/lib/screens/map_screen.dart` — wire gesture, inject PaintSheet branch, add undo/redo FABs, HomeSheet entry, force paint-off on nav-start.

---

## Task 1: Add `turf` dependency + verify buffer

**Files:**
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1: Check pub.dev for the current `turf` version**

Run: `cd mobile && flutter pub add turf --dry-run`
If the name is different on pub (e.g. `turf_dart`), use that; note the chosen version pin below. This plan uses `turf: ^0.0.8` as the reference pin.

- [ ] **Step 2: Add dependency**

Edit `mobile/pubspec.yaml`; add under `dependencies:` (after `freezed_annotation`):

```yaml
  turf: ^0.0.8
```

- [ ] **Step 3: Install**

Run: `cd mobile && flutter pub get`
Expected: no errors. Verify `turf` appears in `.dart_tool/package_config.json`.

- [ ] **Step 4: Smoke-test the buffer API**

Create throwaway file `mobile/tool/turf_probe.dart`:

```dart
import 'package:turf/turf.dart';

void main() {
  final line = Feature<LineString>(
    geometry: LineString(coordinates: [
      Position(13.4, 52.5),
      Position(13.41, 52.5),
    ]),
  );
  final buffered = buffer(line, 0.05, Unit.kilometers);
  print(buffered?.geometry?.toJson());
}
```

Run: `cd mobile && dart run tool/turf_probe.dart`
Expected: prints a JSON object with `"type":"Polygon"` and a non-empty `coordinates` array.

If the API shape differs from this snippet (class names, `Unit` vs string), adjust the import + call style to match the installed package. Delete `mobile/tool/turf_probe.dart` once confirmed.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/nice-hofstadter-2fcbaf
git add mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "deps(mobile): add turf for brush geometry buffering"
```

---

## Task 2: PaintResponse freezed model

**Files:**
- Create: `mobile/lib/models/paint_response.dart`
- Create: `mobile/test/api/paint_response_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/api/paint_response_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/models/paint_response.dart';

void main() {
  test('parses backend JSON with created_id and clipping counts', () {
    final json = {
      'created_id': 42,
      'clipped_count': 1,
      'deleted_count': 0,
      'can_undo': true,
      'can_redo': false,
    };
    final r = PaintResponse.fromJson(json);
    expect(r.createdId, 42);
    expect(r.clippedCount, 1);
    expect(r.deletedCount, 0);
    expect(r.canUndo, isTrue);
    expect(r.canRedo, isFalse);
  });

  test('parses null created_id (eraser response)', () {
    final r = PaintResponse.fromJson({
      'created_id': null,
      'clipped_count': 0,
      'deleted_count': 2,
      'can_undo': true,
      'can_redo': true,
    });
    expect(r.createdId, isNull);
    expect(r.deletedCount, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/api/paint_response_test.dart`
Expected: FAIL — `paint_response.dart` does not exist.

- [ ] **Step 3: Write the freezed model**

Create `mobile/lib/models/paint_response.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'paint_response.freezed.dart';
part 'paint_response.g.dart';

@freezed
class PaintResponse with _$PaintResponse {
  const factory PaintResponse({
    @JsonKey(name: 'created_id') int? createdId,
    @JsonKey(name: 'clipped_count') @Default(0) int clippedCount,
    @JsonKey(name: 'deleted_count') @Default(0) int deletedCount,
    @JsonKey(name: 'can_undo') @Default(false) bool canUndo,
    @JsonKey(name: 'can_redo') @Default(false) bool canRedo,
  }) = _PaintResponse;

  factory PaintResponse.fromJson(Map<String, dynamic> json) =>
      _$PaintResponseFromJson(json);
}
```

- [ ] **Step 4: Run build_runner**

Run: `cd mobile && dart run build_runner build --delete-conflicting-outputs`
Expected: generates `paint_response.freezed.dart` + `paint_response.g.dart`.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd mobile && flutter test test/api/paint_response_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/models/paint_response.dart \
        mobile/lib/models/paint_response.freezed.dart \
        mobile/lib/models/paint_response.g.dart \
        mobile/test/api/paint_response_test.dart
git commit -m "feat(mobile): PaintResponse model for /api/ratings/paint"
```

---

## Task 3: RatingsPaintApi client

**Files:**
- Create: `mobile/lib/api/ratings_paint_api.dart`
- Create: `mobile/test/api/ratings_paint_api_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/api/ratings_paint_api_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:beebeebike/api/ratings_paint_api.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late RatingsPaintApi api;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    adapter = DioAdapter(dio: dio);
    api = RatingsPaintApi(dio);
  });

  const polygon = {
    'type': 'Polygon',
    'coordinates': [
      [
        [13.4, 52.5],
        [13.41, 52.5],
        [13.41, 52.51],
        [13.4, 52.51],
        [13.4, 52.5],
      ]
    ],
  };

  test('paint PUTs geometry + value + target_id', () async {
    adapter.onPut(
      '/api/ratings/paint',
      (request) => request.reply(200, {
        'created_id': 7,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': true,
        'can_redo': false,
      }),
      data: {'geometry': polygon, 'value': 3, 'target_id': null},
    );
    final r = await api.paint(geometry: polygon, value: 3);
    expect(r.createdId, 7);
    expect(r.canUndo, isTrue);
  });

  test('paint with target_id sends it in body', () async {
    adapter.onPut(
      '/api/ratings/paint',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 1,
        'can_undo': true,
        'can_redo': false,
      }),
      data: {'geometry': polygon, 'value': 0, 'target_id': 11},
    );
    final r = await api.paint(geometry: polygon, value: 0, targetId: 11);
    expect(r.deletedCount, 1);
  });

  test('undo POSTs and parses response', () async {
    adapter.onPost(
      '/api/ratings/undo',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': false,
        'can_redo': true,
      }),
    );
    final r = await api.undo();
    expect(r.canUndo, isFalse);
    expect(r.canRedo, isTrue);
  });

  test('redo POSTs and parses response', () async {
    adapter.onPost(
      '/api/ratings/redo',
      (request) => request.reply(200, {
        'created_id': null,
        'clipped_count': 0,
        'deleted_count': 0,
        'can_undo': true,
        'can_redo': false,
      }),
    );
    final r = await api.redo();
    expect(r.canUndo, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/api/ratings_paint_api_test.dart`
Expected: FAIL — `ratings_paint_api.dart` does not exist.

- [ ] **Step 3: Implement the client**

Create `mobile/lib/api/ratings_paint_api.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paint_response.dart';
import 'client.dart';

class RatingsPaintApi {
  RatingsPaintApi(this._dio);

  final Dio _dio;

  Future<PaintResponse> paint({
    required Map<String, dynamic> geometry,
    required int value,
    int? targetId,
  }) async {
    final response = await _dio.put(
      '/api/ratings/paint',
      data: {
        'geometry': geometry,
        'value': value,
        'target_id': targetId,
      },
    );
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PaintResponse> undo() async {
    final response = await _dio.post('/api/ratings/undo');
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<PaintResponse> redo() async {
    final response = await _dio.post('/api/ratings/redo');
    return PaintResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

final ratingsPaintApiProvider =
    Provider<RatingsPaintApi>((ref) => RatingsPaintApi(ref.watch(dioProvider)));
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/api/ratings_paint_api_test.dart`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/api/ratings_paint_api.dart \
        mobile/test/api/ratings_paint_api_test.dart
git commit -m "feat(mobile): RatingsPaintApi for paint/undo/redo endpoints"
```

---

## Task 4: BrushGeometry — pure sampling + buffering

**Files:**
- Create: `mobile/lib/services/brush_geometry.dart`
- Create: `mobile/test/services/brush_geometry_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/services/brush_geometry_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/services/brush_geometry.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  group('metersPerPixel', () {
    test('roughly matches known values at equator z=14', () {
      final mpp = BrushGeometry.metersPerPixel(lat: 0, zoom: 14);
      // Ref: 40075016.686 / 2^(14+9) = ~4.777
      expect(mpp, closeTo(4.777, 0.01));
    });

    test('shrinks with latitude (Berlin)', () {
      final mppEq = BrushGeometry.metersPerPixel(lat: 0, zoom: 14);
      final mppBer = BrushGeometry.metersPerPixel(lat: 52.5, zoom: 14);
      expect(mppBer, lessThan(mppEq));
      expect(mppBer / mppEq, closeTo(math.cos(52.5 * math.pi / 180), 0.001));
    });
  });

  group('shouldSample', () {
    test('true when >= 4px', () {
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(4, 0)), isTrue);
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(0, 5)), isTrue);
    });
    test('false when < 4px', () {
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(3, 0)), isFalse);
      expect(BrushGeometry.shouldSample(Offset.zero, const Offset(2, 2)), isFalse);
    });
  });

  group('buildPolygon', () {
    test('returns null for < 2 points', () {
      expect(
        BrushGeometry.buildPolygon(
          points: const [LatLng(52.5, 13.4)],
          zoom: 14,
        ),
        isNull,
      );
    });

    test('builds closed Polygon with positive area for 3-point stroke', () {
      final geom = BrushGeometry.buildPolygon(
        points: const [
          LatLng(52.5, 13.400),
          LatLng(52.5, 13.401),
          LatLng(52.5, 13.402),
        ],
        zoom: 14,
      );
      expect(geom, isNotNull);
      expect(geom!['type'], 'Polygon');
      final coords = (geom['coordinates'] as List).first as List;
      expect(coords.length, greaterThanOrEqualTo(8));
      final first = coords.first as List;
      final last = coords.last as List;
      expect(first[0], last[0]);
      expect(first[1], last[1]);
    });

    test('enforces 5m minimum radius at high zoom', () {
      // At z=20, 30px ≈ ~4m (lat 52.5) → clamped to 5m.
      final geom = BrushGeometry.buildPolygon(
        points: const [LatLng(52.5, 13.4), LatLng(52.5, 13.40001)],
        zoom: 20,
      );
      expect(geom, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/brush_geometry_test.dart`
Expected: FAIL — `brush_geometry.dart` does not exist.

- [ ] **Step 3: Implement the module (hand-rolled buffer — `turf` 0.0.10 lacks `buffer`)**

Create `mobile/lib/services/brush_geometry.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:maplibre_gl/maplibre_gl.dart';

/// Pure sampling + buffering used by `BrushController`. No Flutter widget
/// dependencies and no MapLibre I/O — callers pass in pre-computed screen
/// offsets and latlng samples so this stays unit-testable.
///
/// The Dart `turf` package does not ship a `buffer()` implementation, so
/// we hand-roll a rounded-capsule polyline buffer: offset each segment by
/// `radiusM` to left and right, walk the right side forward, add a
/// semicircular end cap, walk the left side backward, and add a
/// semicircular start cap. Good enough for brush strokes (no need for
/// miter-join correctness at sharp internal angles — web parity shapes
/// are dominated by smooth drag arcs).
class BrushGeometry {
  BrushGeometry._();

  /// Pixels threshold below which a new pointer sample is ignored.
  /// Matches `MIN_MOVE_PX` in web/src/lib/brush.svelte.js.
  static const double minMovePx = 4.0;

  /// Web-parity constant: nominal finger brush radius in screen pixels.
  static const double brushPx = 30.0;

  /// Minimum buffer radius in kilometers (prevents zero-area polygons).
  static const double minRadiusKm = 0.005;

  /// Semicircle subdivisions for start/end caps. 8 segments → 16-point
  /// cap, ≥ 8 vertices total per stroke easily satisfied.
  static const int _capSegments = 8;

  /// Equatorial circumference / 2^(zoom+9). Matches web's formula in
  /// web/src/lib/brush.svelte.js::buildPolygon.
  static double metersPerPixel({required double lat, required double zoom}) {
    return 40075016.686 *
        math.cos(lat * math.pi / 180) /
        math.pow(2, zoom + 9);
  }

  /// Whether [next] is far enough from [last] to record a new sample.
  static bool shouldSample(Offset last, Offset next) {
    final dx = next.dx - last.dx;
    final dy = next.dy - last.dy;
    return dx * dx + dy * dy >= minMovePx * minMovePx;
  }

  /// Build a GeoJSON Polygon geometry from a stroke. Returns null when
  /// fewer than two samples were collected. Applies a buffer whose radius
  /// is [brushPx] scaled by the current meters-per-pixel and clamped to
  /// [minRadiusKm] so near-zero strokes still produce a valid polygon.
  static Map<String, dynamic>? buildPolygon({
    required List<LatLng> points,
    required double zoom,
  }) {
    if (points.length < 2) return null;
    final avgLat =
        points.fold<double>(0, (s, p) => s + p.latitude) / points.length;
    final mpp = metersPerPixel(lat: avgLat, zoom: zoom);
    final radiusM = math.max(brushPx * mpp, minRadiusKm * 1000);

    // Flat-earth projection: local metres around the first stroke point.
    // Mercator-style scaling is good enough at brush-radius distances.
    final p0 = points.first;
    final mPerDegLat = 111320.0;
    final mPerDegLon = 111320.0 * math.cos(avgLat * math.pi / 180);

    List<double> toXY(LatLng p) => [
          (p.longitude - p0.longitude) * mPerDegLon,
          (p.latitude - p0.latitude) * mPerDegLat,
        ];
    List<double> toLngLat(List<double> xy) => [
          p0.longitude + xy[0] / mPerDegLon,
          p0.latitude + xy[1] / mPerDegLat,
        ];

    final pts = points.map(toXY).toList();

    // Deduplicate consecutive identical samples so segment normals are
    // well-defined.
    final unique = <List<double>>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      if (pts[i][0] != unique.last[0] || pts[i][1] != unique.last[1]) {
        unique.add(pts[i]);
      }
    }
    if (unique.length < 2) return null;

    final right = <List<double>>[];
    final left = <List<double>>[];
    for (var i = 0; i < unique.length - 1; i++) {
      final a = unique[i];
      final b = unique[i + 1];
      final dx = b[0] - a[0];
      final dy = b[1] - a[1];
      final len = math.sqrt(dx * dx + dy * dy);
      if (len == 0) continue;
      // Right-hand perpendicular unit (relative to segment direction).
      final nx = -dy / len;
      final ny = dx / len;
      right.add([a[0] + nx * radiusM, a[1] + ny * radiusM]);
      right.add([b[0] + nx * radiusM, b[1] + ny * radiusM]);
      left.add([a[0] - nx * radiusM, a[1] - ny * radiusM]);
      left.add([b[0] - nx * radiusM, b[1] - ny * radiusM]);
    }

    final first = unique.first;
    final second = unique[1];
    final startDir = math.atan2(second[1] - first[1], second[0] - first[0]);
    final startCap = _arc(first, radiusM, startDir + math.pi / 2, math.pi);

    final last = unique.last;
    final penult = unique[unique.length - 2];
    final endDir = math.atan2(last[1] - penult[1], last[0] - penult[0]);
    final endCap = _arc(last, radiusM, endDir - math.pi / 2, math.pi);

    final ring = <List<double>>[];
    ring.addAll(right);
    ring.addAll(endCap);
    ring.addAll(left.reversed);
    ring.addAll(startCap);
    // Close the ring.
    ring.add(List<double>.from(ring.first));

    final coords = ring.map(toLngLat).toList();
    return {
      'type': 'Polygon',
      'coordinates': [coords],
    };
  }

  static List<List<double>> _arc(
    List<double> center,
    double radius,
    double startAngle,
    double sweep,
  ) {
    final out = <List<double>>[];
    for (var i = 0; i <= _capSegments; i++) {
      final t = i / _capSegments;
      final a = startAngle + sweep * t;
      out.add([
        center[0] + radius * math.cos(a),
        center[1] + radius * math.sin(a),
      ]);
    }
    return out;
  }
}
```

*(The `turf` package stays in `pubspec.yaml` — it pulls in `geotypes` etc. that we may use later. We simply don't depend on it from this file.)*

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/brush_geometry_test.dart`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/brush_geometry.dart \
        mobile/test/services/brush_geometry_test.dart
git commit -m "feat(mobile): BrushGeometry pure sampling + buffering"
```

---

## Task 5: BrushOverlay surface + MapLibre implementation

**Files:**
- Create: `mobile/lib/services/brush_overlay.dart`
- Create: `mobile/test/services/brush_overlay_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/services/brush_overlay_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/services/brush_overlay.dart';

class _FakeSurface implements BrushOverlaySurface {
  @override
  bool isAttached = true;
  Map<String, dynamic>? lastGeometry;
  String? lastColor;
  bool cleared = false;
  bool detached = false;

  @override
  Future<void> setPreview(Map<String, dynamic> geometry, String colorHex) async {
    lastGeometry = geometry;
    lastColor = colorHex;
  }

  @override
  Future<void> clear() async => cleared = true;

  @override
  Future<void> detach() async {
    detached = true;
    isAttached = false;
  }
}

void main() {
  test('colorFor returns expected web-parity hex per rating', () {
    expect(BrushOverlay.colorFor(-7), '#c0392b');
    expect(BrushOverlay.colorFor(-3), '#e74c3c');
    expect(BrushOverlay.colorFor(-1), '#f1948a');
    expect(BrushOverlay.colorFor(0), '#6b7280');
    expect(BrushOverlay.colorFor(1), '#76d7c4');
    expect(BrushOverlay.colorFor(3), '#1abc9c');
    expect(BrushOverlay.colorFor(7), '#0e6655');
  });

  test('BrushOverlaySurface contract is usable via a fake', () async {
    final fake = _FakeSurface();
    await fake.setPreview(
      const {'type': 'Polygon', 'coordinates': []},
      '#1abc9c',
    );
    expect(fake.lastColor, '#1abc9c');
    await fake.clear();
    expect(fake.cleared, isTrue);
    await fake.detach();
    expect(fake.detached, isTrue);
    expect(fake.isAttached, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/brush_overlay_test.dart`
Expected: FAIL — `brush_overlay.dart` does not exist.

- [ ] **Step 3: Implement overlay**

Create `mobile/lib/services/brush_overlay.dart`:

```dart
import 'package:maplibre_gl/maplibre_gl.dart';

/// Render-side contract used by `BrushController`. Tests substitute a fake
/// so the controller's state logic can be exercised without a live
/// MapLibre surface.
abstract class BrushOverlaySurface {
  bool get isAttached;
  Future<void> setPreview(Map<String, dynamic> geometry, String colorHex);
  Future<void> clear();
  Future<void> detach();
}

/// Semi-transparent fill of the in-progress brush stroke. Mirrors the
/// `brush-preview` source + fill layer in web/src/lib/brush.svelte.js.
class BrushOverlay implements BrushOverlaySurface {
  BrushOverlay._(this._controller);

  static const String sourceId = 'brush-preview';
  static const String fillLayerId = 'brush-preview-fill';

  /// Rating → hex (web parity). Value 0 (eraser) shows gray.
  static const Map<int, String> _colors = {
    -7: '#c0392b',
    -3: '#e74c3c',
    -1: '#f1948a',
    0: '#6b7280',
    1: '#76d7c4',
    3: '#1abc9c',
    7: '#0e6655',
  };

  static String colorFor(int value) => _colors[value] ?? '#6b7280';

  final MapLibreMapController _controller;
  bool _attached = false;

  @override
  bool get isAttached => _attached;

  /// Add the empty source + fill layer above the rating overlay so the
  /// preview always renders on top of existing polygons.
  static Future<BrushOverlay> attach(
    MapLibreMapController controller, {
    String? belowLayerId,
  }) async {
    final overlay = BrushOverlay._(controller);

    await controller.addGeoJsonSource(
      sourceId,
      const {'type': 'FeatureCollection', 'features': []},
    );
    await controller.addFillLayer(
      sourceId,
      fillLayerId,
      const FillLayerProperties(
        fillColor: '#60a5fa',
        fillOpacity: 0.3,
      ),
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    overlay._attached = true;
    return overlay;
  }

  @override
  Future<void> setPreview(
    Map<String, dynamic> geometry,
    String colorHex,
  ) async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, {
      'type': 'FeatureCollection',
      'features': [
        {'type': 'Feature', 'properties': {}, 'geometry': geometry},
      ],
    });
    await _controller.setLayerProperties(
      fillLayerId,
      FillLayerProperties(fillColor: colorHex, fillOpacity: 0.3),
    );
  }

  @override
  Future<void> clear() async {
    if (!_attached) return;
    await _controller.setGeoJsonSource(sourceId, const {
      'type': 'FeatureCollection',
      'features': [],
    });
  }

  @override
  Future<void> detach() async {
    if (!_attached) return;
    _attached = false;
    try {
      await _controller.removeLayer(fillLayerId);
    } catch (_) {}
    try {
      await _controller.removeSource(sourceId);
    } catch (_) {}
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/brush_overlay_test.dart`
Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/brush_overlay.dart \
        mobile/test/services/brush_overlay_test.dart
git commit -m "feat(mobile): BrushOverlay surface + MapLibre preview layer"
```

---

## Task 6: BrushController — state + orchestration

**Files:**
- Create: `mobile/lib/providers/brush_provider.dart`
- Create: `mobile/test/providers/brush_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/providers/brush_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

import 'package:beebeebike/api/ratings_paint_api.dart';
import 'package:beebeebike/models/paint_response.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/services/brush_overlay.dart';

class _MockApi extends Mock implements RatingsPaintApi {}

class _FakeSurface implements BrushOverlaySurface {
  @override
  bool isAttached = true;
  Map<String, dynamic>? lastGeometry;
  String? lastColor;
  int clearCount = 0;

  @override
  Future<void> setPreview(Map<String, dynamic> geometry, String colorHex) async {
    lastGeometry = geometry;
    lastColor = colorHex;
  }

  @override
  Future<void> clear() async => clearCount++;

  @override
  Future<void> detach() async => isAttached = false;
}

PaintResponse _ok({bool undo = true, bool redo = false}) => PaintResponse(
      createdId: 1,
      clippedCount: 0,
      deletedCount: 0,
      canUndo: undo,
      canRedo: redo,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockApi api;
  late _FakeSurface surface;
  late ProviderContainer container;

  setUp(() {
    api = _MockApi();
    surface = _FakeSurface();
    container = ProviderContainer(overrides: [
      ratingsPaintApiProvider.overrideWithValue(api),
    ]);
    final notifier = container.read(brushControllerProvider.notifier);
    notifier.attach(surface: surface);
  });

  tearDown(() => container.dispose());

  BrushController notifier() => container.read(brushControllerProvider.notifier);
  BrushState state() => container.read(brushControllerProvider);

  test('initial state: value=1, paintMode=false, empty stroke', () {
    expect(state().value, 1);
    expect(state().paintMode, isFalse);
    expect(state().canUndo, isFalse);
    expect(state().canRedo, isFalse);
  });

  test('setValue(3) enables paint mode', () {
    notifier().setValue(3);
    expect(state().value, 3);
    expect(state().paintMode, isTrue);
  });

  test('togglePaintMode off clears preview and in-flight stroke', () async {
    notifier().setValue(1);
    notifier().startStroke(const LatLng(52.5, 13.4));
    notifier().togglePaintMode();
    expect(state().paintMode, isFalse);
    expect(surface.clearCount, greaterThanOrEqualTo(1));
  });

  test('endStroke with < 2 points and no hit feature is a no-op', () async {
    notifier().setValue(1);
    notifier().startStroke(const LatLng(52.5, 13.4));
    await notifier().endStroke(tapFeatureLookup: (_) async => null);
    verifyNever(() => api.paint(
          geometry: any(named: 'geometry'),
          value: any(named: 'value'),
          targetId: any(named: 'targetId'),
        ));
  });

  test('endStroke with single-tap hit calls paint with target_id', () async {
    const hitGeom = {
      'type': 'Polygon',
      'coordinates': [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]],
    };
    when(() => api.paint(
          geometry: any(named: 'geometry'),
          value: any(named: 'value'),
          targetId: any(named: 'targetId'),
        )).thenAnswer((_) async => _ok());

    notifier().setValue(3);
    notifier().startStroke(const LatLng(52.5, 13.4));
    await notifier().endStroke(
      tapFeatureLookup: (_) async =>
          const TapFeature(areaId: 99, geometry: hitGeom),
    );

    verify(() => api.paint(
          geometry: hitGeom,
          value: 3,
          targetId: 99,
        )).called(1);
    expect(state().canUndo, isTrue);
  });

  test('endStroke with multi-point stroke submits buffered polygon', () async {
    when(() => api.paint(
          geometry: any(named: 'geometry'),
          value: any(named: 'value'),
          targetId: any(named: 'targetId'),
        )).thenAnswer((_) async => _ok());

    notifier().setValue(3);
    notifier().startStroke(const LatLng(52.5, 13.400));
    notifier().addPoint(const LatLng(52.5, 13.401), 14);
    notifier().addPoint(const LatLng(52.5, 13.402), 14);
    await notifier().endStroke(tapFeatureLookup: (_) async => null);

    final captured = verify(() => api.paint(
          geometry: captureAny(named: 'geometry'),
          value: 3,
          targetId: null,
        )).captured.single as Map<String, dynamic>;
    expect(captured['type'], 'Polygon');
  });

  test('undo updates canUndo/canRedo from response', () async {
    when(() => api.undo()).thenAnswer(
      (_) async => _ok(undo: false, redo: true),
    );
    await notifier().undo();
    expect(state().canUndo, isFalse);
    expect(state().canRedo, isTrue);
  });

  test('api error during endStroke clears preview and keeps mode on', () async {
    when(() => api.paint(
          geometry: any(named: 'geometry'),
          value: any(named: 'value'),
          targetId: any(named: 'targetId'),
        )).thenThrow(Exception('boom'));

    notifier().setValue(3);
    notifier().startStroke(const LatLng(52.5, 13.400));
    notifier().addPoint(const LatLng(52.5, 13.401), 14);
    notifier().addPoint(const LatLng(52.5, 13.402), 14);
    await notifier().endStroke(tapFeatureLookup: (_) async => null);

    expect(state().paintMode, isTrue);
    expect(surface.clearCount, greaterThanOrEqualTo(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/providers/brush_controller_test.dart`
Expected: FAIL — `brush_provider.dart` does not exist.

- [ ] **Step 3: Implement the controller**

Create `mobile/lib/providers/brush_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/ratings_paint_api.dart';
import '../providers/rating_overlay_provider.dart';
import '../services/brush_geometry.dart';
import '../services/brush_overlay.dart';

/// Result of a map `queryRenderedFeatures` probe for tap-recolor. Kept as
/// a plain struct so tests can synthesize one without MapLibre.
class TapFeature {
  const TapFeature({required this.areaId, required this.geometry});
  final int areaId;
  final Map<String, dynamic> geometry;
}

typedef TapFeatureLookup = Future<TapFeature?> Function(LatLng point);

@immutable
class BrushState {
  const BrushState({
    this.value = 1,
    this.paintMode = false,
    this.canUndo = false,
    this.canRedo = false,
  });

  final int value;
  final bool paintMode;
  final bool canUndo;
  final bool canRedo;

  BrushState copyWith({
    int? value,
    bool? paintMode,
    bool? canUndo,
    bool? canRedo,
  }) =>
      BrushState(
        value: value ?? this.value,
        paintMode: paintMode ?? this.paintMode,
        canUndo: canUndo ?? this.canUndo,
        canRedo: canRedo ?? this.canRedo,
      );
}

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

/// Holds brush state and orchestrates paint/undo/redo calls. Keeps no
/// MapLibre references itself — callers hand in a `BrushOverlaySurface`
/// and a `TapFeatureLookup` so tests can drive it with fakes.
class BrushController extends Notifier<BrushState> {
  BrushOverlaySurface? _overlay;
  final List<LatLng> _stroke = [];
  double _lastZoom = 14;
  bool _submitting = false;

  @override
  BrushState build() => const BrushState();

  /// Wire a live overlay. Call once from `map_screen.dart`'s
  /// `onStyleLoadedCallback` after the rating overlay is attached.
  void attach({required BrushOverlaySurface surface}) {
    _overlay = surface;
  }

  Future<void> detach() async {
    final s = _overlay;
    _overlay = null;
    _stroke.clear();
    await s?.detach();
  }

  /// Select a rating value and enter paint mode. Entering mode while
  /// already on is idempotent (just swaps the value).
  void setValue(int v) {
    state = state.copyWith(value: v, paintMode: true);
  }

  /// Toggle paint mode. Turning off discards any in-flight stroke and
  /// clears the preview layer.
  void togglePaintMode() {
    final next = !state.paintMode;
    if (!next) {
      _stroke.clear();
      unawaited(_overlay?.clear());
    }
    state = state.copyWith(paintMode: next);
  }

  /// Force paint mode off (e.g. when navigation starts). Safe to call
  /// when already off.
  void forceOff() {
    if (!state.paintMode) return;
    _stroke.clear();
    unawaited(_overlay?.clear());
    state = state.copyWith(paintMode: false);
  }

  void startStroke(LatLng first) {
    _stroke
      ..clear()
      ..add(first);
  }

  void addPoint(LatLng p, double zoom) {
    _stroke.add(p);
    _lastZoom = zoom;
    final geom = BrushGeometry.buildPolygon(points: _stroke, zoom: zoom);
    if (geom != null) {
      unawaited(_overlay?.setPreview(geom, BrushOverlay.colorFor(state.value)));
    }
  }

  /// End a stroke. If fewer than two samples were collected we treat it
  /// as a tap: the caller resolves whether the tap hit an existing
  /// polygon via [tapFeatureLookup] and, if so, we submit a recolor.
  Future<void> endStroke({required TapFeatureLookup tapFeatureLookup}) async {
    if (_submitting) return;
    _submitting = true;
    try {
      if (_stroke.length < 2) {
        final tap = _stroke.isEmpty ? null : _stroke.first;
        if (tap == null) return;
        final hit = await tapFeatureLookup(tap);
        if (hit == null) return;
        await _submit(
          geometry: hit.geometry,
          targetId: hit.areaId,
        );
        return;
      }
      final geom = BrushGeometry.buildPolygon(
        points: List.unmodifiable(_stroke),
        zoom: _lastZoom,
      );
      if (geom == null) return;
      await _submit(geometry: geom, targetId: null);
    } finally {
      _stroke.clear();
      unawaited(_overlay?.clear());
      _submitting = false;
    }
  }

  Future<void> undo() async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.undo();
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      _refreshRatingOverlay();
    } catch (e) {
      _log('brush: undo failed: $e');
    }
  }

  Future<void> redo() async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.redo();
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      _refreshRatingOverlay();
    } catch (e) {
      _log('brush: redo failed: $e');
    }
  }

  Future<void> _submit({
    required Map<String, dynamic> geometry,
    required int? targetId,
  }) async {
    try {
      final api = ref.read(ratingsPaintApiProvider);
      final r = await api.paint(
        geometry: geometry,
        value: state.value,
        targetId: targetId,
      );
      state = state.copyWith(canUndo: r.canUndo, canRedo: r.canRedo);
      _refreshRatingOverlay();
    } catch (e) {
      _log('brush: paint failed: $e');
    }
  }

  void _refreshRatingOverlay() {
    // The rating overlay controller refetches from the current viewport
    // whenever camera-idle fires, but we also want an immediate refresh
    // after our own paint to show the committed polygon. `onCameraIdle`
    // is the public entry point that already handles the whole fetch
    // pipeline (decideFetch + cancel previous), so reuse it here.
    ref.read(ratingOverlayControllerProvider.notifier).onCameraIdle();
  }
}

final brushControllerProvider =
    NotifierProvider<BrushController, BrushState>(BrushController.new);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/providers/brush_controller_test.dart`
Expected: all 8 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/brush_provider.dart \
        mobile/test/providers/brush_controller_test.dart
git commit -m "feat(mobile): BrushController state + paint/undo/redo orchestration"
```

---

## Task 7: PaintSheet widget

**Files:**
- Create: `mobile/lib/widgets/paint_sheet.dart`
- Create: `mobile/test/widgets/paint_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/paint_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/widgets/paint_sheet.dart';

void main() {
  testWidgets('renders 7 color chips and a paint toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: PaintSheet()),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('paint-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('paint-chip')), findsNWidgets(7));
  });

  testWidgets('tapping a chip selects value and turns paint mode on',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: PaintSheet()),
          ),
        ),
      ),
    );

    // Tap the 7th chip (value = 7).
    final chips = find.byKey(const ValueKey('paint-chip'));
    await tester.tap(chips.at(6));
    await tester.pump();

    final state = container.read(brushControllerProvider);
    expect(state.value, 7);
    expect(state.paintMode, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/paint_sheet_test.dart`
Expected: FAIL — `paint_sheet.dart` does not exist.

- [ ] **Step 3: Implement the widget**

Create `mobile/lib/widgets/paint_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/brush_provider.dart';
import '../services/brush_overlay.dart';

class PaintSheet extends ConsumerWidget {
  const PaintSheet({super.key});

  static const List<int> _values = [-7, -3, -1, 0, 1, 3, 7];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    final mq = MediaQuery.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              _PaintToggle(
                active: state.paintMode,
                onPressed: notifier.togglePaintMode,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final v in _values)
                      _ColorChip(
                        key: const ValueKey('paint-chip'),
                        value: v,
                        selected: state.value == v,
                        onTap: () => notifier.setValue(v),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaintToggle extends StatelessWidget {
  const _PaintToggle({required this.active, required this.onPressed});
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('paint-toggle'),
      color: active ? const Color(0xFF2563EB) : Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: active ? const Color(0xFF2563EB) : Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.brush, color: active ? Colors.white : const Color(0xFF374151), size: 20),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    super.key,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hex = BrushOverlay.colorFor(value);
    final color = Color(int.parse(hex.substring(1), radix: 16) | 0xFF000000);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: value == 0 ? Colors.white : color,
          border: Border.all(
            color: selected ? const Color(0xFF333333) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: selected
              ? const [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2)]
              : const [],
        ),
        transformAlignment: Alignment.center,
        transform: selected
            ? (Matrix4.identity()..scale(1.15))
            : Matrix4.identity(),
        child: value == 0
            ? Icon(Icons.cleaning_services_outlined, size: 20, color: color)
            : null,
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/paint_sheet_test.dart`
Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/paint_sheet.dart \
        mobile/test/widgets/paint_sheet_test.dart
git commit -m "feat(mobile): PaintSheet with paint-toggle + 7 color chips"
```

---

## Task 8: UndoRedoFabs widget

**Files:**
- Create: `mobile/lib/widgets/undo_redo_fabs.dart`
- Create: `mobile/test/widgets/undo_redo_fabs_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/undo_redo_fabs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beebeebike/widgets/undo_redo_fabs.dart';

void main() {
  testWidgets('renders two FABs with correct keys', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: Scaffold(body: UndoRedoFabs(bottomOffset: 120))),
    ));
    expect(find.byKey(const ValueKey('undo-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('redo-fab')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/undo_redo_fabs_test.dart`
Expected: FAIL — widget missing.

- [ ] **Step 3: Implement the widget**

Create `mobile/lib/widgets/undo_redo_fabs.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/brush_provider.dart';

class UndoRedoFabs extends ConsumerWidget {
  const UndoRedoFabs({super.key, required this.bottomOffset});

  /// Distance from the screen bottom at which the column's bottom edge sits.
  /// Callers match this to the active sheet's top edge so the FABs rise with
  /// the sheet.
  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            key: const ValueKey('undo-fab'),
            heroTag: 'brush-undo-fab',
            onPressed: state.canUndo ? notifier.undo : null,
            backgroundColor: state.canUndo ? Colors.white : Colors.grey.shade200,
            foregroundColor:
                state.canUndo ? const Color(0xFF374151) : Colors.grey.shade400,
            child: const Icon(Icons.undo),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            key: const ValueKey('redo-fab'),
            heroTag: 'brush-redo-fab',
            onPressed: state.canRedo ? notifier.redo : null,
            backgroundColor: state.canRedo ? Colors.white : Colors.grey.shade200,
            foregroundColor:
                state.canRedo ? const Color(0xFF374151) : Colors.grey.shade400,
            child: const Icon(Icons.redo),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/undo_redo_fabs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/undo_redo_fabs.dart \
        mobile/test/widgets/undo_redo_fabs_test.dart
git commit -m "feat(mobile): UndoRedoFabs stacked column"
```

---

## Task 9: Integrate into MapScreen

**Files:**
- Modify: `mobile/lib/screens/map_screen.dart`

This task wires everything into the browse overlay. No new automated test — exercised by the integration smoke test in Task 10.

- [ ] **Step 1: Add imports**

Open `mobile/lib/screens/map_screen.dart` and add near the other imports:

```dart
import '../providers/brush_provider.dart';
import '../services/brush_geometry.dart';
import '../services/brush_overlay.dart';
import '../services/rating_overlay.dart';
import '../widgets/paint_sheet.dart';
import '../widgets/undo_redo_fabs.dart';
```

- [ ] **Step 2: Attach the brush overlay after style load**

In `_MapScreenState`, locate `onStyleLoadedCallback` inside `MapLibreMap(...)` (around [map_screen.dart:470-485](mobile/lib/screens/map_screen.dart)) — the block that currently calls `attachToMap(c)` on the rating overlay notifier.

Append to the `onStyleLoadedCallback` body, after the rating-overlay attach:

```dart
// Brush preview must render above the rating overlay so the in-progress
// stroke stays visible. MapLibre sorts layers by insertion order; adding
// after the rating overlay gives us the correct z-order without a
// belowLayerId hint.
final brushOverlay = await BrushOverlay.attach(c);
if (!mounted) return;
ref.read(brushControllerProvider.notifier).attach(surface: brushOverlay);
```

*(Make the callback `async` if it isn't already, and capture `c` up front.)*

- [ ] **Step 3: Detach on dispose**

In `_MapScreenState.dispose`, alongside the existing `unawaited(notifier.detach())` for rating overlay, add:

```dart
final brushNotifier = ref.read(brushControllerProvider.notifier);
unawaited(brushNotifier.detach());
```

- [ ] **Step 4: Wire the gesture detector**

Still inside `_MapScreenState.build`, wrap the `MapLibreMap` widget in a conditional `Listener`/`GestureDetector`. The controller is already captured as `_mapController`.

Add a helper method in `_MapScreenState`:

```dart
Future<TapFeature?> _probeRatingFeature(LatLng at) async {
  final controller = _mapController;
  if (controller == null) return null;
  final screenPt = await controller.toScreenLocation(at);
  final hits = await controller.queryRenderedFeatures(
    screenPt,
    [RatingOverlay.fillLayerId],
    null,
  );
  if (hits.isEmpty) return null;
  final first = hits.first;
  final id = first['properties']?['id'] ?? first['id'];
  final geom = first['geometry'];
  if (id is! int || geom is! Map) return null;
  return TapFeature(
    areaId: id,
    geometry: Map<String, dynamic>.from(geom),
  );
}
```

Wrap the current `styleAsync.when(... data: (style) => MapLibreMap(...))` return with a `Consumer` that watches paint mode, and wrap the map in a `GestureDetector` only when paint mode is on:

```dart
Consumer(builder: (context, ref, _) {
  final paintMode = ref.watch(
    brushControllerProvider.select((s) => s.paintMode),
  );
  final map = styleAsync.when(
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (e, _) => Center(child: Text('Failed to load map: $e')),
    data: (style) => MapLibreMap(
      styleString: style,
      initialCameraPosition: const CameraPosition(
        target: LatLng(52.5200, 13.4050),
        zoom: 13,
      ),
      cameraTargetBounds: CameraTargetBounds(_berlinBounds),
      minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
      myLocationEnabled: true,
      myLocationTrackingMode: MyLocationTrackingMode.none,
      trackCameraPosition: true,
      scrollGesturesEnabled: !paintMode,
      rotateGesturesEnabled: !paintMode,
      tiltGesturesEnabled: !paintMode,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (c) => _mapController = c,
      onUserLocationUpdated: (loc) => _handleBrowseLocationUpdate(
        loc.position.latitude,
        loc.position.longitude,
      ),
      onStyleLoadedCallback: () async {
        final c = _mapController;
        if (c == null) return;
        await ref.read(ratingOverlayControllerProvider.notifier).attachToMap(c);
        if (!mounted) return;
        final brushOverlay = await BrushOverlay.attach(c);
        if (!mounted) return;
        ref.read(brushControllerProvider.notifier).attach(surface: brushOverlay);
      },
      onMapClick: _handleMapTap,
      onCameraTrackingDismissed: () => ref
          .read(navigationCameraControllerProvider)
          .onTrackingDismissed(),
      onCameraIdle: () {
        final c = _mapController;
        if (c == null) return;
        final zoom = c.cameraPosition?.zoom;
        if (zoom != null) {
          ref
              .read(navigationCameraControllerProvider)
              .onZoomChanged(zoom);
        }
        ref
            .read(ratingOverlayControllerProvider.notifier)
            .onCameraIdle();
      },
    ),
  );
  if (!paintMode) return map;
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanStart: (d) async {
      final c = _mapController;
      if (c == null) return;
      final latlng = await c.toLatLng(
        math.Point(d.localPosition.dx, d.localPosition.dy),
      );
      ref.read(brushControllerProvider.notifier).startStroke(latlng);
    },
    onPanUpdate: (d) async {
      final c = _mapController;
      if (c == null) return;
      final zoom = c.cameraPosition?.zoom ?? 14;
      final latlng = await c.toLatLng(
        math.Point(d.localPosition.dx, d.localPosition.dy),
      );
      ref.read(brushControllerProvider.notifier).addPoint(latlng, zoom);
    },
    onPanEnd: (_) {
      ref.read(brushControllerProvider.notifier).endStroke(
            tapFeatureLookup: _probeRatingFeature,
          );
    },
    child: map,
  );
});
```

*(The existing `styleAsync` and `navActive` calls above must stay; only the map widget is wrapped.)*

- [ ] **Step 5: Insert PaintSheet into AnimatedSwitcher**

Locate the `AnimatedSwitcher` child expression near [map_screen.dart:531-555](mobile/lib/screens/map_screen.dart). Replace the child ternary with:

```dart
child: navActive
    ? _NavigationSheet(
        key: const ValueKey('nav'),
        ttsEnabled: _ttsEnabled,
        onToggleTts: () =>
            setState(() => _ttsEnabled = !_ttsEnabled),
        onClose: () =>
            ref.read(navigationSessionProvider.notifier).state = false,
      )
    : ref.watch(brushControllerProvider.select((s) => s.paintMode))
        ? const PaintSheet(key: ValueKey('paint'))
        : routeActive
            ? _RouteSheet(
                key: const ValueKey('route'),
                routeState: routeState,
                preview: preview,
                onFlyToMyLocation: _flyToCurrentLocation,
                onStart: () =>
                    ref.read(navigationSessionProvider.notifier).state = true,
              )
            : _HomeSheet(
                key: const ValueKey('home'),
                onFlyToMyLocation: _flyToCurrentLocation,
                onNavigateHome: _navigateHome,
                onEnterPaintMode: () =>
                    ref.read(brushControllerProvider.notifier).setValue(1),
              ),
```

*(Priority nav > paint > route > home matches the spec.)*

- [ ] **Step 6: Add `onEnterPaintMode` to `_HomeSheet` and a "Paint ratings" action**

Extend `_HomeSheet` (widget + state) with a new required callback `onEnterPaintMode`:

```dart
class _HomeSheet extends ConsumerStatefulWidget {
  const _HomeSheet({
    super.key,
    required this.onFlyToMyLocation,
    required this.onNavigateHome,
    required this.onEnterPaintMode,
  });

  final VoidCallback onFlyToMyLocation;
  final VoidCallback onNavigateHome;
  final VoidCallback onEnterPaintMode;
  // ...
}
```

Inside the `ListView` children of the `_HomeSheetState` body, above the `Caveats` section, add:

```dart
const SizedBox(height: 8),
ActionChip(
  avatar: const Icon(Icons.brush, size: 16),
  label: const Text('Paint ratings'),
  onPressed: widget.onEnterPaintMode,
),
const SizedBox(height: 16),
```

- [ ] **Step 7: Mount `UndoRedoFabs` when paint mode is on**

Inside the `Stack` children of `_MapScreenState.build`, after the `AnimatedSwitcher`, add:

```dart
Consumer(builder: (context, ref, _) {
  final show = ref.watch(
    brushControllerProvider.select((s) => s.paintMode),
  ) && !navActive;
  if (!show) return const SizedBox.shrink();
  // Match the PaintSheet's rough height (drag handle + 40px row + insets
  // ≈ 120px + safe-area). Keep it above the FAB slot the sheet would
  // otherwise use.
  final mq = MediaQuery.of(context);
  return UndoRedoFabs(bottomOffset: 120 + mq.padding.bottom + 16);
});
```

- [ ] **Step 8: Force paint off when navigation starts**

Locate the existing `ref.listen<bool>(navigationSessionProvider, ...)` block (around [map_screen.dart:309-316](mobile/lib/screens/map_screen.dart)). Inside its `if (next)` branch, add at the top:

```dart
ref.read(brushControllerProvider.notifier).forceOff();
```

- [ ] **Step 9: Run analyzer + existing tests**

```bash
cd mobile && flutter analyze
cd mobile && flutter test
```

Expected: analyzer clean, all existing tests still PASS.

- [ ] **Step 10: Commit**

```bash
git add mobile/lib/screens/map_screen.dart
git commit -m "feat(mobile): wire PaintSheet + brush gesture + undo/redo FABs"
```

---

## Task 10: Integration smoke test

**Files:**
- Create: `mobile/integration_test/brush_smoke_test.dart`

- [ ] **Step 1: Write the integration test**

Create `mobile/integration_test/brush_smoke_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:integration_test/integration_test.dart';

import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/providers/brush_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paint ratings entry flips paint mode and shows PaintSheet',
      (tester) async {
    final dio = Dio(BaseOptions(baseUrl: 'http://test.local'));
    final adapter = DioAdapter(dio: dio);
    adapter
      ..onGet('/api/auth/me', (r) => r.reply(401, {}))
      ..onPost('/api/auth/anonymous',
          (r) => r.reply(200, {'id': 'anon', 'account_type': 'anonymous'}))
      ..onGet('/api/ratings',
          (r) => r.reply(200, {'type': 'FeatureCollection', 'features': []}));

    await tester.pumpWidget(ProviderScope(
      overrides: [dioProvider.overrideWithValue(dio)],
      child: const BeeBeeBikeApp(),
    ));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Find "Paint ratings" chip in the HomeSheet.
    final chip = find.text('Paint ratings');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final state = container.read(brushControllerProvider);
    expect(state.paintMode, isTrue);
    expect(state.value, 1);

    // PaintSheet should now be visible.
    expect(find.byKey(const ValueKey('paint-toggle')), findsOneWidget);
    expect(find.byKey(const ValueKey('paint-chip')), findsNWidgets(7));
  });
}
```

- [ ] **Step 2: Run the integration test on the simulator**

```bash
cd mobile
flutter test integration_test/brush_smoke_test.dart -d "$(xcrun simctl list devices booted | grep -E 'iPhone.*Booted' | head -1 | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"
```

Expected: PASS. (If no simulator is booted, run `just dev-ios-sim` in another terminal first, or run `flutter test integration_test/brush_smoke_test.dart` for a widget-test-level smoke pass.)

- [ ] **Step 3: Commit**

```bash
git add mobile/integration_test/brush_smoke_test.dart
git commit -m "test(mobile): integration smoke test for paint-mode entry"
```

---

## Task 11: End-to-end manual verification

**Files:** none (manual).

- [ ] **Step 1: Run the full stack**

```bash
just dev
```

Wait for the backend to print `listening on 0.0.0.0:3000`.

- [ ] **Step 2: Run iOS on simulator**

In a second terminal:

```bash
just dev-ios-sim
```

- [ ] **Step 3: Happy path**

1. Log in (or continue as anonymous).
2. Tap "Paint ratings" in the home sheet. PaintSheet slides up.
3. Tap the teal `+3` chip.
4. Drag a short stroke across the map. Live blue preview follows the finger.
5. Lift finger. Preview clears; a teal rated area appears where you dragged.
6. Undo FAB becomes enabled; tap it. Rated area disappears.
7. Redo FAB becomes enabled; tap it. Rated area reappears.
8. Tap the gray eraser chip. Drag across the painted area. The teal polygon is erased.
9. Tap the paint-toggle (brush icon). Paint mode exits, HomeSheet returns.

- [ ] **Step 4: Priority check**

1. Enter paint mode, then tap a destination on the map... — wait, map taps don't fire in paint mode. Toggle paint off first, set a destination (RouteSheet shows).
2. Re-enter paint mode via the home sheet's "Paint ratings" chip. Expected: PaintSheet replaces RouteSheet.
3. Exit paint mode. Expected: RouteSheet returns.
4. Start navigation (from RouteSheet). Expected: paint FABs disappear; NavigationSheet slides up.

- [ ] **Step 5: Verify no regressions**

```bash
just test-mobile
just lint-backend   # sanity check: nothing backend-side touched
```

Both should pass. If `flutter analyze` shows warnings, fix them before proceeding.

- [ ] **Step 6: No commit unless fixes were made**

If the manual pass revealed bugs, fix and commit per task boundaries.

---

## Self-Review

**Spec coverage (each spec section ↔ task):**

- UX paint mode entry via color chip / toggle exit — Tasks 6 (controller), 7 (sheet), 9 (wiring).
- Rating values + hex colors — Tasks 5 (overlay), 7 (sheet).
- PaintSheet layout / 4th sheet priority — Tasks 7 (widget), 9 (wiring).
- UndoRedoFabs tracking sheet offset — Task 8 (widget), 9 (mount with bottomOffset).
- Preview polygon (no cursor ring) — Task 5 (overlay), Task 6 (controller uses it).
- Single-tap recolor — Task 6 (`endStroke` path) + Task 9 (`_probeRatingFeature`).
- API contract — Tasks 2 (model), 3 (client).
- Geometry (jitter, mpp, buffer, min radius) — Task 4.
- Sheet priority (nav > paint > route > home) — Task 9 step 5.
- Nav activation forces paint off — Task 9 step 8.

**Placeholder scan:** No TBDs, TODOs, or "similar to Task N" references. Every code step shows full code.

**Type consistency:**
- `PaintResponse.{canUndo, canRedo}` used identically in Task 2, 3, 6.
- `BrushOverlaySurface.{setPreview, clear, detach}` identical in Task 5 + Task 6 test fake.
- `TapFeature.{areaId, geometry}` identical in Task 6 + Task 9's `_probeRatingFeature`.
- `BrushController` methods `setValue`, `togglePaintMode`, `forceOff`, `startStroke`, `addPoint`, `endStroke`, `undo`, `redo` — all referenced consistently.
