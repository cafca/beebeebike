import 'package:beebeebike/dev/playback_controller.dart';
import 'package:beebeebike/dev/widgets/playback_drawer.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

RoutePreview _preview() => const RoutePreview(
      geometry: {
        'type': 'LineString',
        'coordinates': [
          [0.0, 0.0],
          [0.001, 0.0],
          [0.003, 0.0],
        ],
      },
      distance: 333.96,
      time: 33400, // ms
    );

class _FakeRouteController extends Notifier<RouteState>
    implements RouteController {
  _FakeRouteController(this._initial);
  final RouteState _initial;
  @override
  RouteState build() => _initial;
  @override
  Never noSuchMethod(Invocation i) => throw UnimplementedError(i.toString());
}

Widget _wrap(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: PlaybackDrawer()),
      ),
    );

void main() {
  testWidgets('renders icon buttons for play/restart/back/forward/speed',
      (tester) async {
    final c = ProviderContainer(overrides: [
      routeControllerProvider.overrideWith(
        () => _FakeRouteController(RouteState(preview: _preview())),
      ),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playback-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('playback-restart')), findsOneWidget);
    expect(find.byKey(const ValueKey('playback-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('playback-forward')), findsOneWidget);
    expect(find.byKey(const ValueKey('playback-speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('playback-progress')), findsOneWidget);
  });

  testWidgets('tap play flips isPlaying true', (tester) async {
    final c = ProviderContainer(overrides: [
      routeControllerProvider.overrideWith(
        () => _FakeRouteController(RouteState(preview: _preview())),
      ),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-play')));
    await tester.pumpAndSettle();
    expect(c.read(playbackControllerProvider).isPlaying, isTrue);
  });

  testWidgets('tap speed cycles multiplier', (tester) async {
    final c = ProviderContainer(overrides: [
      routeControllerProvider.overrideWith(
        () => _FakeRouteController(RouteState(preview: _preview())),
      ),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-speed')));
    await tester.pumpAndSettle();
    expect(c.read(playbackControllerProvider).speedMultiplier, 2.0);
  });

  testWidgets('disables controls when no route loaded', (tester) async {
    final c = ProviderContainer(overrides: [
      routeControllerProvider.overrideWith(
        () => _FakeRouteController(const RouteState()),
      ),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_wrap(c));
    await tester.pumpAndSettle();
    final btn = tester.widget<IconButton>(
      find.byKey(const ValueKey('playback-play')),
    );
    expect(btn.onPressed, isNull);
  });
}
