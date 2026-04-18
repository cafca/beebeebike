import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../navigation/navigation_service.dart';
import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../services/map_style_loader.dart';
import '../services/route_drawing.dart';
import '../widgets/turn_banner.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late final NavigationService _navigationService;
  MapLibreMapController? _mapController;
  RouteOverlay? _routeOverlay;
  bool _ttsEnabled = true;

  @override
  void initState() {
    super.initState();
    _navigationService = ref.read(navigationServiceProvider);
    _startNavigation();
  }

  @override
  void dispose() {
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (origin == null || destination == null) return;

    try {
      await _navigationService.start(
        origin: WaypointInput(lat: origin.lat, lng: origin.lng),
        destination:
            WaypointInput(lat: destination.lat, lng: destination.lng),
      );
    } catch (e, st) {
      debugPrint('NavigationScreen: failed to start navigation: $e\n$st');
    }
  }

  Future<void> _drawRouteIfReady() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_routeOverlay != null) return;
    final preview = ref.read(routeControllerProvider).preview;
    if (preview == null) return;
    _routeOverlay = await RouteOverlay.draw(controller, preview);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final styleAsync = ref.watch(mapStyleProvider);

    return Scaffold(
      body: Stack(
        children: [
          styleAsync.when(
            loading: () => const ColoredBox(color: Color(0xFFCFE3D3)),
            error: (e, _) => Center(child: Text('Map error: $e')),
            data: (style) => MapLibreMap(
              styleString: style,
              initialCameraPosition: const CameraPosition(
                target: LatLng(52.5200, 13.4050),
                zoom: 15,
              ),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.trackingCompass,
              trackCameraPosition: true,
              onMapCreated: (controller) async {
                _mapController = controller;
                await _drawRouteIfReady();
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: navState.when(
                loading: () => const TurnBanner(
                  primaryText: 'Starting navigation...',
                  distanceText: '',
                ),
                error: (e, _) => const TurnBanner(
                  primaryText: 'Navigation error',
                  distanceText: '',
                  icon: Icons.error_outline,
                ),
                data: (state) => TurnBanner(
                  primaryText: state.currentVisual?.primaryText ?? 'On route',
                  distanceText: state.progress != null
                      ? _formatDistance(
                          state.progress!.distanceToNextManeuverM)
                      : '',
                  icon: state.currentVisual != null
                      ? _iconForManeuver(
                          state.currentVisual!.maneuverType,
                          state.currentVisual!.maneuverModifier,
                        )
                      : Icons.straight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    navState.when(
                      loading: () => const Text('Loading...'),
                      error: (_, __) => const Text('—'),
                      data: (state) {
                        final p = state.progress;
                        if (p == null) return const Text('—');
                        return Text(_formatEta(p.durationRemainingMs));
                      },
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_ttsEnabled
                              ? Icons.volume_up
                              : Icons.volume_off),
                          onPressed: () {
                            setState(() => _ttsEnabled = !_ttsEnabled);
                            // TODO: wire to NavigationService TTS mute when
                            // the underlying ferrostar plugin exposes it.
                          },
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForManeuver(String type, String? modifier) {
  final mod = modifier?.replaceAll('_', ' ');
  if (type == 'turn') {
    if (mod == 'left') return Icons.turn_left;
    if (mod == 'right') return Icons.turn_right;
    if (mod == 'sharp left') return Icons.turn_sharp_left;
    if (mod == 'sharp right') return Icons.turn_sharp_right;
    if (mod == 'slight left') return Icons.turn_slight_left;
    if (mod == 'slight right') return Icons.turn_slight_right;
  }
  if (type == 'arrive') return Icons.flag;
  return Icons.straight;
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatEta(int durationRemainingMs) {
  final eta =
      DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  final minRemaining = (durationRemainingMs / 60000).round();
  return '$h:$m arrival · $minRemaining min';
}
