import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';

void main() {
  test('setDestination computes a preview when origin already exists', () async {
    final container = ProviderContainer(overrides: [
      routePreviewLoaderProvider.overrideWithValue(
        ({required origin, required destination}) async => RoutePreview(
          geometry: const {'type': 'LineString', 'coordinates': []},
          distance: 3200,
          time: 720,
        ),
      ),
    ]);
    addTearDown(container.dispose);

    await container.read(routeControllerProvider.notifier).setOrigin(
          const Location(id: 'o', name: 'origin', label: 'Origin', lng: 13.4, lat: 52.5),
        );
    await container.read(routeControllerProvider.notifier).setDestination(
          const Location(id: 'd', name: 'destination', label: 'Destination', lng: 13.45, lat: 52.51),
        );

    expect(container.read(routeControllerProvider).preview?.distance, 3200);
  });

  test('re-fetches route preview when user logs in', () async {
    var callCount = 0;
    final container = ProviderContainer(overrides: [
      routePreviewLoaderProvider.overrideWithValue(
        ({required origin, required destination}) async {
          callCount++;
          return RoutePreview(
            geometry: const {'type': 'LineString', 'coordinates': []},
            distance: 1000.0 * callCount,
            time: 300000.0,
          );
        },
      ),
      authControllerProvider.overrideWith(() => _FakeAuthController()),
    ]);
    addTearDown(container.dispose);

    // Set up a route while anonymous.
    await container.read(routeControllerProvider.notifier).setOrigin(
          const Location(id: 'o', name: 'origin', label: 'Origin', lng: 13.4, lat: 52.5),
        );
    await container.read(routeControllerProvider.notifier).setDestination(
          const Location(id: 'd', name: 'dest', label: 'Dest', lng: 13.45, lat: 52.51),
        );
    expect(callCount, 1);

    // Simulate login: anonymous → real user.
    (container.read(authControllerProvider.notifier) as _FakeAuthController)
        .simulateLogin();
    // Allow Riverpod listeners to fire.
    await Future.delayed(Duration.zero);

    expect(callCount, 2);
    expect(container.read(routeControllerProvider).preview?.distance, 2000.0);
  });
}

class _FakeAuthController extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'anon', accountType: 'anonymous');

  void simulateLogin() {
    state = const AsyncData(User(id: 'u1', email: 'a@b.com', accountType: 'registered'));
  }
}
