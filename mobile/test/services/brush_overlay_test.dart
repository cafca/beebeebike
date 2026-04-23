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
