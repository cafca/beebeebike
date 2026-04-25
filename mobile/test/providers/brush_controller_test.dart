import 'package:beebeebike/api/ratings_paint_api.dart';
import 'package:beebeebike/models/paint_response.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/services/brush_overlay.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';

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
    container.read(brushControllerProvider.notifier).attach(surface);
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

  test('endStroke with < 2 points is a no-op', () async {
    notifier().setValue(1);
    notifier().startStroke(const LatLng(52.5, 13.4));
    await notifier().endStroke();
    verifyNever(() => api.paint(
          geometry: any(named: 'geometry'),
          value: any(named: 'value'),
          targetId: any(named: 'targetId'),
        ));
  });

  test('recolorFromLongPress calls paint with target_id', () async {
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
    await notifier().recolorFromLongPress(
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
    await notifier().endStroke();

    final captured = verify(() => api.paint(
          geometry: captureAny(named: 'geometry'),
          value: 3,
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
    await notifier().endStroke();

    expect(state().paintMode, isTrue);
    expect(surface.clearCount, greaterThanOrEqualTo(1));
  });
}
