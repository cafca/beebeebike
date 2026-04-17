import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
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
}
