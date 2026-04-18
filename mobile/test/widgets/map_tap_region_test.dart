import 'package:beebeebike/widgets/map_tap_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapTapRegion', () {
    Widget wrap(ValueChanged<Offset> onTap, {Widget? child}) {
      return MaterialApp(
        home: SizedBox(
          width: 400,
          height: 600,
          child: MapTapRegion(
            onTap: onTap,
            child: child ??
                Container(
                  width: 400,
                  height: 600,
                  color: const Color(0xFFEEEEEE),
                ),
          ),
        ),
      );
    }

    testWidgets('single tap fires onTap with local offset',
        (tester) async {
      Offset? tapped;
      await tester.pumpWidget(wrap((o) => tapped = o));

      await tester.tapAt(const Offset(120, 200));
      await tester.pumpAndSettle();

      expect(tapped, isNotNull);
      expect(tapped!.dx, closeTo(120, 1));
      expect(tapped!.dy, closeTo(200, 1));
    });

    testWidgets('drag does not fire onTap', (tester) async {
      Offset? tapped;
      await tester.pumpWidget(wrap((o) => tapped = o));

      await tester.dragFrom(const Offset(50, 50), const Offset(80, 80));
      await tester.pumpAndSettle();

      expect(tapped, isNull);
    });

    testWidgets('long press does not fire onTap', (tester) async {
      Offset? tapped;
      await tester.pumpWidget(wrap((o) => tapped = o));

      await tester.longPressAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(tapped, isNull);
    });

    testWidgets('multi-touch does not fire onTap (regression guard)',
        (tester) async {
      Offset? tapped;
      await tester.pumpWidget(wrap((o) => tapped = o));

      final g1 = await tester.startGesture(const Offset(100, 200));
      final g2 = await tester.startGesture(const Offset(300, 200));
      // Simulate pinch: spread fingers apart.
      await g1.moveBy(const Offset(-30, 0));
      await g2.moveBy(const Offset(30, 0));
      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();

      expect(tapped, isNull,
          reason:
              'Multi-touch must not be reported as a tap; otherwise the '
              'underlying platform view loses gestures like pinch.');
    });
  });
}
