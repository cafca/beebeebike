import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

import '../navigation/camera_controller.dart';
import '../navigation/navigation_service.dart';
import '../providers/navigation_camera_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../services/map_style_loader.dart';
import '../services/route_drawing.dart';
import '../widgets/arrived_sheet.dart';
import '../widgets/recenter_fab.dart';
import '../widgets/rerouting_toast.dart';
import '../widgets/turn_banner.dart';

const _defaultCenter = LatLng(52.5200, 13.4050);
const _followZoomOnStart = 17.0;

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
  bool _rerouting = false;

  @override
  void initState() {
    super.initState();
    _navigationService = ref.read(navigationServiceProvider);
    _startNavigation();
  }

  @override
  void dispose() {
    final c = _mapController;
    final o = _routeOverlay;
    if (c != null && o != null) {
      o.remove(c); // fire-and-forget
    }
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
    _routeOverlay =
        await RouteOverlay.draw(controller, preview, fitCamera: false);
  }

  Future<void> _handleFirstFix(UserLocation loc) async {
    final controller = _mapController;
    if (controller == null) return;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onFirstFix();
    await controller
        .animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(loc.lat, loc.lng), cam.followZoom));
    if (!mounted) return;
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
  }

  Future<void> _handleArrival() async {
    final controller = _mapController;
    if (controller == null) return;
    final destination = ref.read(routeControllerProvider).destination;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onArrived();
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.none);
    if (!mounted) return;
    if (destination != null) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(destination.lat, destination.lng), 17));
    }
  }

  Future<void> _handleRecenterTap() async {
    final controller = _mapController;
    if (controller == null) return;
    final snapped = ref.read(navigationStateProvider).value?.snappedLocation;
    if (snapped == null) return;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onRecenterTapped();
    await controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(snapped.lat, snapped.lng), cam.followZoom));
    if (!mounted) return;
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
  }

  void _onNavStateChange(
      AsyncValue<NavigationState>? prev, AsyncValue<NavigationState> next) {
    if (!mounted) return;
    final prevState = prev?.value;
    final nextState = next.value;
    if (nextState == null) return;

    if (prevState?.snappedLocation == null &&
        nextState.snappedLocation != null) {
      _handleFirstFix(nextState.snappedLocation!);
    }

    if ((prevState?.isOffRoute ?? false) != nextState.isOffRoute) {
      setState(() => _rerouting = nextState.isOffRoute);
    }

    if (prevState?.status != TripStatus.complete &&
        nextState.status == TripStatus.complete) {
      _handleArrival();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final styleAsync = ref.watch(mapStyleProvider);
    final cam = ref.watch(navigationCameraControllerProvider);
    final origin = ref.watch(routeControllerProvider).origin;

    ref.listen<AsyncValue<NavigationState>>(
        navigationStateProvider, _onNavStateChange);

    final initialTarget =
        origin != null ? LatLng(origin.lat, origin.lng) : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          styleAsync.when(
            loading: () => const ColoredBox(color: Color(0xFFCFE3D3)),
            error: (e, _) => Center(child: Text('Map error: $e')),
            data: (style) => MapLibreMap(
              styleString: style,
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _followZoomOnStart,
              ),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              trackCameraPosition: true,
              onMapCreated: (controller) async {
                _mapController = controller;
                await _drawRouteIfReady();
              },
              onCameraTrackingDismissed: () {
                ref
                    .read(navigationCameraControllerProvider)
                    .onTrackingDismissed();
              },
              onCameraIdle: () {
                final c = _mapController;
                if (c == null) return;
                final zoom = c.cameraPosition?.zoom;
                if (zoom != null) {
                  ref
                      .read(navigationCameraControllerProvider)
                      .onZoomChanged(zoom);
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navState.when(
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
                      primaryText:
                          state.currentVisual?.primaryText ?? 'On route',
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
                  if (_rerouting) const ReroutingToast(),
                ],
              ),
            ),
          ),
          if (cam.mode == CameraMode.free)
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 140),
                  child: RecenterFab(onTap: _handleRecenterTap),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: cam.mode == CameraMode.arrived
                    ? ArrivedSheet(onDone: () => Navigator.of(context).pop())
                    : _EtaSheet(
                        navState: navState,
                        ttsEnabled: _ttsEnabled,
                        onToggleTts: () =>
                            setState(() => _ttsEnabled = !_ttsEnabled),
                        onClose: () => Navigator.of(context).pop(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaSheet extends StatelessWidget {
  const _EtaSheet({
    required this.navState,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.onClose,
  });

  final AsyncValue<NavigationState> navState;
  final bool ttsEnabled;
  final VoidCallback onToggleTts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
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
                icon: Icon(
                    ttsEnabled ? Icons.volume_up : Icons.volume_off),
                onPressed: onToggleTts,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close),
              ),
            ],
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
