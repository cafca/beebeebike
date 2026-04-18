import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/geocode_result.dart';
import '../models/location.dart';
import '../models/route_state.dart';
import '../providers/route_provider.dart';
import '../screens/navigation_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../services/map_style_loader.dart';
import '../services/route_drawing.dart';
import '../widgets/map_tap_region.dart';
import '../widgets/route_summary.dart';
import '../widgets/search_bar.dart';

final _berlinBounds = LatLngBounds(
  southwest: const LatLng(52.3, 13.0),
  northeast: const LatLng(52.7, 13.8),
);

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  MapLibreMapController? _mapController;
  RouteOverlay? _routeOverlay;

  Future<void> _handleMapTap(Offset localPosition) async {
    final controller = _mapController;
    if (controller == null) return;
    final coords = await controller.toLatLng(
      Point<double>(localPosition.dx, localPosition.dy),
    );
    if (!mounted) return;
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
  }

  Future<void> _onRouteStateChanged(
      RouteState? previous, RouteState next) async {
    final controller = _mapController;
    if (controller == null) return;
    if (previous?.preview == next.preview) return;

    final existing = _routeOverlay;
    if (existing != null) {
      await existing.remove(controller);
      _routeOverlay = null;
    }
    final preview = next.preview;
    if (preview != null) {
      _routeOverlay = await RouteOverlay.draw(controller, preview);
    }
  }

  Future<void> _flyToCurrentLocation() async {
    final controller = _mapController;
    if (controller == null) return;
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get current location: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeControllerProvider);
    final preview = routeState.preview;
    final styleAsync = ref.watch(mapStyleProvider);

    ref.listen<RouteState>(routeControllerProvider, _onRouteStateChanged);

    return Scaffold(
      body: Stack(
        children: [
          styleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load map: $e')),
            data: (style) => MapTapRegion(
              onTap: _handleMapTap,
              child: MapLibreMap(
                styleString: style,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(52.5200, 13.4050),
                  zoom: 13,
                ),
                cameraTargetBounds: CameraTargetBounds(_berlinBounds),
                minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
                myLocationEnabled: true,
                myLocationTrackingMode: MyLocationTrackingMode.none,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
            ),
          ),
          BeeBeeBikeSearchBar(
            onTap: () async {
              final result = await Navigator.of(context).push<GeocodeResult>(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              if (result == null || !context.mounted) return;

              Position? pos;
              try {
                pos = await Geolocator.getLastKnownPosition() ??
                    await Geolocator.getCurrentPosition();
              } catch (_) {}
              if (!context.mounted) return;
              ref.read(routeControllerProvider.notifier).setOrigin(
                    Location(
                      id: 'gps',
                      name: 'Current location',
                      label: 'Current location',
                      lng: pos?.longitude ?? 13.4533,
                      lat: pos?.latitude ?? 52.5065,
                    ),
                  );
              if (!context.mounted) return;
              ref.read(routeControllerProvider.notifier).setDestination(
                    Location(
                      id: result.id,
                      name: result.name,
                      label: result.label,
                      lng: result.lng,
                      lat: result.lat,
                    ),
                  );
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
                    onPressed: _flyToCurrentLocation,
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
                                    // GraphHopper returns time in milliseconds.
                                    durationMinutes:
                                        (preview.time / 60000).round(),
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
