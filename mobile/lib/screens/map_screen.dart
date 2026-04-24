import 'dart:async';
import 'dart:math' as math;

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../models/route_state.dart';
import '../navigation/location_converter.dart';
import '../navigation/nav_constants.dart';
import '../providers/navigation_camera_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/navigation_session_provider.dart';
import '../providers/location_provider.dart';
import '../providers/map_bearing_provider.dart';
import '../providers/rating_overlay_provider.dart';
import '../providers/route_provider.dart';
import '../services/haptics.dart';
import '../services/home_marker_service.dart';
import '../services/map_style_loader.dart';
import '../services/route_drawing.dart';
import '../widgets/map/home_sheet_container.dart';
import '../widgets/map/nav_top_bar.dart';
import '../widgets/map/navigation_sheet.dart';
import '../widgets/map/route_sheet.dart';
import '../widgets/route_card.dart';

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
  final HomeMarkerService _homeMarker = HomeMarkerService();
  RatingOverlayController? _ratingOverlayNotifier;
  bool _ttsEnabled = true;
  bool _rerouting = false;
  bool _browseAutocentered = false;

  Future<void> _handleMapTap(math.Point<double> point, LatLng coords) async {
    if (ref.read(navigationSessionProvider)) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(routeControllerProvider.notifier);
    if (ref.read(routeControllerProvider).origin == null) {
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition();
      } catch (_) {}
      if (!mounted) return;
      notifier.setOrigin(
        Location(
          id: 'gps',
          name: l10n.locationCurrent,
          label: l10n.locationCurrent,
          lng: pos?.longitude ?? 13.4533,
          lat: pos?.latitude ?? 52.5065,
        ),
      );
    }
    notifier.setDestination(
      Location(
        id: 'geo:${coords.latitude},${coords.longitude}',
        name:
            '${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)}',
        label: l10n.locationDroppedPin,
        lng: coords.longitude,
        lat: coords.latitude,
      ),
    );
  }

  Future<void> _onRouteStateChanged(
      RouteState? previous, RouteState next) async {
    final controller = _mapController;
    if (controller == null) return;

    final inNav = ref.read(navigationSessionProvider);
    final mq = MediaQuery.of(context);

    // Fly to origin+destination immediately when destination is first set,
    // so the map moves while the route is still calculating.
    if (!inNav &&
        previous?.destination != next.destination &&
        next.destination != null) {
      final origin = next.origin;
      final dest = next.destination!;
      if (origin != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                math.min(origin.lat, dest.lat),
                math.min(origin.lng, dest.lng),
              ),
              northeast: LatLng(
                math.max(origin.lat, dest.lat),
                math.max(origin.lng, dest.lng),
              ),
            ),
            left: 40.0,
            top: mq.padding.top + 117.0,
            right: 40.0,
            bottom: mq.padding.bottom + 224.0,
          ),
        );
      }
    }

    if (previous?.preview == next.preview) return;

    EdgeInsets? fitPadding;
    if (!inNav && previous?.preview == null && next.preview != null) {
      fitPadding = EdgeInsets.only(
        top: mq.padding.top + 117.0,
        bottom: mq.padding.bottom + 224.0,
        left: 40.0,
        right: 40.0,
      );
    }

    final existing = _routeOverlay;
    if (existing != null) {
      await existing.remove(controller);
      _routeOverlay = null;
    }
    if (!mounted) return;
    final preview = next.preview;
    if (preview != null) {
      _routeOverlay =
          await RouteOverlay.draw(controller, preview, fitPadding: fitPadding);
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.locationFetchError(e.toString()))),
      );
    }
  }

  Future<void> _navigateHome() async {
    final home = ref.read(homeLocationProvider).valueOrNull;
    if (home == null) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(routeControllerProvider.notifier);
    if (ref.read(routeControllerProvider).origin == null) {
      Position? pos;
      try {
        pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition();
      } catch (_) {}
      if (!mounted) return;
      notifier.setOrigin(Location(
        id: 'gps',
        name: l10n.locationCurrent,
        label: l10n.locationCurrent,
        lng: pos?.longitude ?? 13.4533,
        lat: pos?.latitude ?? 52.5065,
      ));
    }
    notifier.setDestination(Location(
      id: home.id,
      name: l10n.settingsHome,
      label: home.label,
      lng: home.lng,
      lat: home.lat,
    ));
  }

  Future<void> _updateHomeMarker(Location? home) async {
    final controller = _mapController;
    if (controller == null) return;
    await _homeMarker.update(controller, home);
  }

  Future<void> _handleBrowseLocationUpdate(double lat, double lng) async {
    if (_browseAutocentered) return;
    if (ref.read(navigationSessionProvider)) return;
    final controller = _mapController;
    if (controller == null) return;
    _browseAutocentered = true;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
    );
  }

  Future<void> _startNavigationSession() async {
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (origin == null || destination == null) {
      debugPrint('nav: start aborted (no origin/destination)');
      return;
    }
    debugPrint('nav: start ${origin.name} -> ${destination.name}');
    final service = ref.read(navigationServiceProvider);
    // Fetch last-known position synchronously (no GPS wait) so the controller
    // has an initial fix and NavigationState emits immediately.
    UserLocation? initial;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) initial = positionToUserLocation(pos);
    } catch (_) {}
    try {
      await service.start(
        origin: WaypointInput(lat: origin.lat, lng: origin.lng),
        destination:
            WaypointInput(lat: destination.lat, lng: destination.lng),
        initialLocation: initial,
      );
    } catch (e, st) {
      debugPrint('nav: start failed: $e\n$st');
    }
  }

  Future<void> _endNavigationSession({bool clearRoute = false}) async {
    debugPrint('nav: end (clearRoute=$clearRoute)');
    final service = ref.read(navigationServiceProvider);
    await service.dispose();
    final controller = _mapController;
    if (controller != null) {
      await controller
          .updateMyLocationTrackingMode(MyLocationTrackingMode.none);
      // Reorient to north — trackingCompass may have rotated the map during
      // navigation, and browse mode should always face north-up.
      await controller.animateCamera(CameraUpdate.bearingTo(0));
    }
    if (!mounted) return;
    setState(() {
      _rerouting = false;
      _browseAutocentered = false;
    });
    ref.read(navigationSessionProvider.notifier).state = false;
    if (clearRoute) {
      ref.read(routeControllerProvider.notifier).clear();
    }
  }

  Future<void> _handleFirstFix(UserLocation loc) async {
    debugPrint('nav: first fix');
    AppHaptics.firstFix();
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onFirstFix();
    final controller = _mapController;
    if (controller == null) return;
    // Enable tracking first so maplibre drives the camera target, then
    // apply zoom. newLatLngZoom before trackingCompass gets clobbered —
    // the tracking mode kicks in and resets zoom to whatever it was.
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
    if (!mounted) return;
    await controller.animateCamera(CameraUpdate.zoomTo(cam.followZoom));
  }

  Future<void> _handleArrival() async {
    debugPrint('nav: arrived');
    AppHaptics.arrived();
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onArrived();
    if (mounted) setState(() => _rerouting = false);
    final controller = _mapController;
    if (controller == null) return;
    final destination = ref.read(routeControllerProvider).destination;
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.none);
    if (!mounted) return;
    if (destination != null) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(destination.lat, destination.lng), kArrivalZoom));
    }
  }

  Future<void> _resetBearingToNorth() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.bearingTo(0));
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
    if (!ref.read(navigationSessionProvider)) return;
    final prevState = prev?.value;
    final nextState = next.value;
    if (nextState == null) return;

    if (prevState?.snappedLocation == null &&
        nextState.snappedLocation != null) {
      _handleFirstFix(nextState.snappedLocation!);
    }

    if (prevState?.status != TripStatus.complete &&
        nextState.status == TripStatus.complete) {
      _handleArrival();
    }
  }

  void _onRerouteInProgressChange(
      AsyncValue<bool>? prev, AsyncValue<bool> next) {
    if (!mounted) return;
    final prevInProgress = prev?.value ?? false;
    final inProgress = next.value ?? false;
    if (_rerouting != inProgress) {
      debugPrint('nav: reroute ${inProgress ? "start" : "done"}');
      setState(() => _rerouting = inProgress);
    }
    // On reroute completion, refetch the preview polyline so the map
    // shows the new route. `/api/navigate` used during reroute returns
    // an encoded polyline (not GeoJSON), so the RoutePreview geometry
    // isn't updated by ferrostar's replaceRoute. Re-hitting `/api/route`
    // with current GPS as origin produces a fresh GeoJSON preview.
    if (prevInProgress && !inProgress) {
      _refreshPreviewFromGps();
    }
  }

  Future<void> _refreshPreviewFromGps() async {
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
    } catch (e) {
      debugPrint('nav: refresh-preview GPS error: $e');
    }
    if (!mounted || pos == null) return;
    final l10n = AppLocalizations.of(context)!;
    ref.read(routeControllerProvider.notifier).setOrigin(
          Location(
            id: 'gps',
            name: l10n.locationCurrent,
            label: l10n.locationCurrent,
            lat: pos.latitude,
            lng: pos.longitude,
          ),
        );
  }

  @override
  void dispose() {
    // Detach rating overlay before MapLibre tears down its surface to
    // avoid leaking the source + layers through hot restarts. `dispose`
    // can't be async, so we explicitly mark the detach future as
    // fire-and-forget; the work is quick (removeLayer / removeSource) and
    // safe to race against MapLibre's own teardown because detach swallows
    // errors from an already-destroyed surface. We use the cached notifier
    // because `ref` is not usable once the element is being disposed.
    final notifier = _ratingOverlayNotifier;
    if (notifier != null) unawaited(notifier.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Cache the notifier on first build so dispose() can call detach()
    // without touching `ref` after unmount.
    _ratingOverlayNotifier ??=
        ref.read(ratingOverlayControllerProvider.notifier);
    final routeState = ref.watch(routeControllerProvider);
    final preview = routeState.preview;
    final styleAsync = ref.watch(mapStyleProvider);
    final navActive = ref.watch(navigationSessionProvider);
    final routeActive = routeState.isLoading ||
        routeState.error != null ||
        preview != null;

    ref.listen<AsyncValue<Location?>>(homeLocationProvider, (_, next) {
      _updateHomeMarker(next.valueOrNull);
    });
    ref.listen<RatingOverlayState>(ratingOverlayControllerProvider,
        (prev, next) {
      // One-shot toast: fires exactly when liveSyncDegraded flips false→true.
      // Happens once per app session (either the client flag is off, or the
      // server 404s the SSE endpoint on first connect).
      if (prev?.liveSyncDegraded != true && next.liveSyncDegraded) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Live sync unavailable. Painted areas update on next app start.'),
          ),
        );
      }
    });
    ref.listen<RouteState>(routeControllerProvider, _onRouteStateChanged);
    ref.listen<AsyncValue<NavigationState>>(
        navigationStateProvider, _onNavStateChange);
    ref.listen<AsyncValue<bool>>(
        rerouteInProgressProvider, _onRerouteInProgressChange);
    ref.listen<bool>(navigationSessionProvider, (prev, next) {
      if (prev == next) return;
      if (next) {
        _startNavigationSession();
      } else if (prev == true) {
        _endNavigationSession();
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          styleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text(l10n.mapLoadError(e.toString()))),
            data: (style) => MapLibreMap(
              styleString: style,
              initialCameraPosition: const CameraPosition(
                target: LatLng(52.5200, 13.4050),
                zoom: 13,
              ),
              cameraTargetBounds: CameraTargetBounds(_berlinBounds),
              minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              trackCameraPosition: true,
              // Hide built-in compass + attribution chrome. Compass is
              // redrawn inline above each RecenterFab (CompassFabInline);
              // attribution is inlined under each sheet's CTA (MapAttribution).
              compassEnabled: false,
              attributionButtonMargins: const math.Point(-1000, -1000),
              // EagerGestureRecognizer: map claims all pointer events so pinch,
              // rotate and pan work when wrapped in a Scaffold/MaterialApp
              // that otherwise wins the gesture arena on iOS.
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onUserLocationUpdated: (loc) => _handleBrowseLocationUpdate(
                  loc.position.latitude, loc.position.longitude),
              onStyleLoadedCallback: () {
                // Attach rating overlay AFTER style is loaded — MapLibre
                // silently ignores addGeoJsonSource / addLayer calls made
                // before the style is ready. Route line and markers are
                // added later via the annotation APIs and sit above all
                // custom style layers by default, so the overlay stays
                // visually below them. `attachToMap` is idempotent in case
                // the style reloads.
                final c = _mapController;
                if (c == null) return;
                ref
                    .read(ratingOverlayControllerProvider.notifier)
                    .attachToMap(c);
                _updateHomeMarker(ref.read(homeLocationProvider).valueOrNull);
              },
              onMapClick: _handleMapTap,
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
                final bearing = c.cameraPosition?.bearing ?? 0;
                final current = ref.read(mapBearingProvider);
                if ((bearing - current).abs() > 0.1) {
                  ref.read(mapBearingProvider.notifier).state = bearing;
                }
              },
            ),
          ),
          if (!navActive)
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: RouteCard(),
              ),
            ),
          if (navActive)
            NavTopBar(
              ttsEnabled: _ttsEnabled,
              rerouting: _rerouting,
              onToggleTts: () => setState(() => _ttsEnabled = !_ttsEnabled),
              onRecenter: _handleRecenterTap,
              onResetBearing: _resetBearingToNorth,
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
            child: navActive
                ? NavigationSheet(
                    key: const ValueKey('nav'),
                    onClose: () =>
                        ref.read(navigationSessionProvider.notifier).state =
                            false,
                  )
                : routeActive
                    ? RouteSheet(
                        key: const ValueKey('route'),
                        routeState: routeState,
                        preview: preview,
                        onFlyToMyLocation: _flyToCurrentLocation,
                        onResetBearing: _resetBearingToNorth,
                        onStart: () {
                          AppHaptics.startRide();
                          ref
                              .read(navigationSessionProvider.notifier)
                              .state = true;
                        },
                      )
                    : HomeSheetContainer(
                        key: const ValueKey('home'),
                        onFlyToMyLocation: _flyToCurrentLocation,
                        onResetBearing: _resetBearingToNorth,
                        onNavigateHome: _navigateHome,
                      ),
          ),
        ],
      ),
    );
  }
}
