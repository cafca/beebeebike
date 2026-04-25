import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:beebeebike/dev/playback_controller.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/providers/route_provider.dart';

RoutePreview _fixturePreview() => const RoutePreview(
      geometry: {
        'type': 'LineString',
        'coordinates': [
          [0.0, 0.0],
          [0.001, 0.0],
          [0.003, 0.0],
        ],
      },
      distance: 333.96,
      time: 33400, // ms; ~10 m/s
    );

class _FakeRouteController extends Notifier<RouteState>
    implements RouteController {
  _FakeRouteController(this._initial);
  final RouteState _initial;
  @override
  RouteState build() => _initial;

  void emit(RouteState s) => state = s;

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('PlaybackController', () {
    test('seeds engine when route preview becomes available', () {
      final container = ProviderContainer(overrides: [
        routeControllerProvider.overrideWith(
          () => _FakeRouteController(RouteState(preview: _fixturePreview())),
        ),
      ]);
      addTearDown(container.dispose);
      final state = container.read(playbackControllerProvider);
      expect(state.routeLengthM, closeTo(333.96, 1.0));
      expect(state.routeBaseSpeedMps, closeTo(10.0, 0.1));
    });

    test('returns empty state when no route', () {
      final container = ProviderContainer(overrides: [
        routeControllerProvider.overrideWith(
          () => _FakeRouteController(const RouteState()),
        ),
      ]);
      addTearDown(container.dispose);
      final state = container.read(playbackControllerProvider);
      expect(state.routeLengthM, 0.0);
    });

    test('play / pause / seek mutate state', () {
      final container = ProviderContainer(overrides: [
        routeControllerProvider.overrideWith(
          () => _FakeRouteController(RouteState(preview: _fixturePreview())),
        ),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(playbackControllerProvider.notifier);
      notifier.play();
      expect(container.read(playbackControllerProvider).isPlaying, isTrue);
      notifier.pause();
      expect(container.read(playbackControllerProvider).isPlaying, isFalse);
      notifier.seek(50);
      expect(container.read(playbackControllerProvider).cumulativeM, 50.0);
    });

    test('cycleSpeed walks through preset multipliers', () {
      final container = ProviderContainer(overrides: [
        routeControllerProvider.overrideWith(
          () => _FakeRouteController(RouteState(preview: _fixturePreview())),
        ),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(playbackControllerProvider.notifier);
      notifier.cycleSpeed();
      expect(container.read(playbackControllerProvider).speedMultiplier, 2.0);
      notifier.cycleSpeed();
      expect(container.read(playbackControllerProvider).speedMultiplier, 5.0);
      notifier.cycleSpeed();
      expect(container.read(playbackControllerProvider).speedMultiplier, 10.0);
      notifier.cycleSpeed();
      expect(container.read(playbackControllerProvider).speedMultiplier, 0.5);
      notifier.cycleSpeed();
      expect(container.read(playbackControllerProvider).speedMultiplier, 1.0);
    });

    test('setOverride / clearOverride round-trip', () {
      final container = ProviderContainer(overrides: [
        routeControllerProvider.overrideWith(
          () => _FakeRouteController(RouteState(preview: _fixturePreview())),
        ),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(playbackControllerProvider.notifier);
      notifier.setOverride(const LatLng(1, 2));
      expect(container.read(playbackControllerProvider).overrideLatLng,
          isNotNull);
      notifier.clearOverride();
      expect(container.read(playbackControllerProvider).overrideLatLng, isNull);
    });
  });
}
