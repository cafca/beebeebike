import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../app.dart';
import '../models/geocode_result.dart';
import '../models/location.dart';
import '../providers/route_provider.dart';
import '../screens/navigation_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/route_summary.dart';
import '../widgets/search_bar.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(routeControllerProvider);
    final preview = routeState.preview;

    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: ref.watch(appConfigProvider).tileStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: LatLng(52.5200, 13.4050),
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            gestureRecognizers: {
              Factory<EagerGestureRecognizer>(
                  () => EagerGestureRecognizer()),
            },
            onMapClick: (Point<double> point, LatLng coords) {
              ref.read(routeControllerProvider.notifier).setDestination(
                    Location(
                      id: 'geo:${coords.latitude},${coords.longitude}',
                      name:
                          '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}',
                      label: 'Dropped pin',
                      lng: coords.longitude,
                      lat: coords.latitude,
                    ),
                  );
            },
          ),
          BeeBeeBikeSearchBar(
            onTap: () async {
              final result =
                  await Navigator.of(context).push<GeocodeResult>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (result == null || !context.mounted) return;

              Position? pos;
              try {
                pos = await Geolocator.getLastKnownPosition() ??
                    await Geolocator.getCurrentPosition();
              } catch (_) {}
              if (pos != null && context.mounted) {
                ref.read(routeControllerProvider.notifier).setOrigin(
                      Location(
                        id: 'gps',
                        name: 'Current location',
                        label: 'Current location',
                        lng: pos.longitude,
                        lat: pos.latitude,
                      ),
                    );
              }
              if (context.mounted) {
                ref.read(routeControllerProvider.notifier).setDestination(
                      Location(
                        id: result.id,
                        name: result.name,
                        label: result.label,
                        lng: result.lng,
                        lat: result.lat,
                      ),
                    );
              }
            },
            onAvatarTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    onPressed: () {},
                    child: const Icon(Icons.my_location),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: routeState.isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : routeState.error != null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Could not load route',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              )
                            : preview == null
                                ? const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: SizedBox(
                                          width: 36,
                                          child: Divider(thickness: 4),
                                        ),
                                      ),
                                      SizedBox(height: 12),
                                      Text('Home'),
                                      Text('Saved places'),
                                    ],
                                  )
                                : RouteSummary(
                                    durationMinutes:
                                        (preview.time / 60).round(),
                                    distanceKm: preview.distance / 1000,
                                    onStart: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NavigationScreen(),
                                      ),
                                    ),
                                  ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
