import 'package:beebeebike/services/brush_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSurface implements BrushOverlaySurface {
  @override
  bool isAttached = true;
  Map<String, dynamic>? lastGeometry;
  String? lastColor;
  bool cleared = false;
  bool detached = false;

  @override
  Future<void> setPreview(
      Map<String, dynamic> geometry, String colorHex) async {
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
  test('colorFor returns expected design-ramp hex per rating', () {
    expect(BrushOverlay.colorFor(-7), '#B8342E');
    expect(BrushOverlay.colorFor(-3), '#D94A4A');
    expect(BrushOverlay.colorFor(-1), '#EF8379');
    expect(BrushOverlay.colorFor(0), '#8A95A1');
    expect(BrushOverlay.colorFor(1), '#7FD9C9');
    expect(BrushOverlay.colorFor(3), '#2EB8A8');
    expect(BrushOverlay.colorFor(7), '#0E7E72');
  });

  test('BrushOverlaySurface contract is usable via a fake', () async {
    final fake = _FakeSurface();
    await fake.setPreview(
      const <String, dynamic>{'type': 'Polygon', 'coordinates': <dynamic>[]},
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
