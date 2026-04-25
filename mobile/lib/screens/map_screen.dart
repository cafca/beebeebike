import 'dart:async';
import 'dart:math' as math;

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;
import 'package:maplibre_gl/maplibre_gl.dart' as ml show UserLocation;

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../models/route_state.dart';
import '../navigation/camera_controller.dart';
import '../navigation/location_converter.dart';
import '../navigation/nav_constants.dart';
import '../providers/brush_provider.dart';
import '../providers/navigation_camera_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/navigation_session_provider.dart';
import '../providers/location_provider.dart';
import '../providers/map_bearing_provider.dart';
import '../providers/rating_overlay_provider.dart';
import '../providers/route_provider.dart';
import '../providers/user_location_provider.dart';
import '../services/brush_overlay.dart';
import '../services/error_reporter.dart';
import '../services/haptics.dart';
import '../services/home_marker_service.dart';
import '../services/map_style_loader.dart';
import '../services/rating_overlay.dart';
import '../services/route_drawing.dart';
import '../theme/tokens.dart';
import '../widgets/brush_fab.dart';
import '../widgets/map/home_sheet_container.dart';
import '../widgets/map/nav_top_bar.dart';
import '../widgets/map/navigation_sheet.dart';
import '../widgets/map/route_sheet.dart';
import '../widgets/paint_sheet.dart';
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
  BrushOverlay? _brushOverlay;
  BrushController? _brushNotifier;
  bool _rerouting = false;
  bool _browseAutocentered = false;
  int _paintPointerCount = 0;
  bool _paintMultiTouch = false;

  Future<void> _handleMapTap(math.Point<double> point, LatLng coords) async {
    if (ref.read(navigationSessionProvider)) return;
    if (ref.read(brushControllerProvider).paintMode) return;
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(routeControllerProvider.notifier);
    if (ref.read(routeControllerProvider).origin == null) {
      final origin = await _resolveCurrentOriginLocation(l10n);
      if (!mounted) return;
      notifier.setOrigin(origin);
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

    // Dim the existing overlay while a recompute is in flight (preview
    // unchanged, isLoading toggling). Replacement below handles the
    // un-dim path by redrawing from scratch at full opacity.
    if (previous?.isLoading != next.isLoading && next.preview != null) {
      final overlay = _routeOverlay;
      if (overlay != null) {
        await overlay.setDimmed(controller, next.isLoading);
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
      final origin = await _resolveCurrentOriginLocation(l10n);
      if (!mounted) return;
      notifier.setOrigin(origin);
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

  /// Single entry point for MapLibre's user-location callback. Caches the
  /// fix in userLocationProvider (used to seed nav, pick route origins, and
  /// fall back recenter when ferrostar hasn't snapped yet), auto-centers in
  /// browse mode on first fix, and — edge case — promotes the camera into
  /// following mode if nav started before any fix was cached.
  Future<void> _onUserLocationUpdated(ml.UserLocation loc) async {
    final uloc = maplibreToUserLocation(loc);
    ref.read(userLocationProvider.notifier).state = uloc;
    if (ref.read(navigationSessionProvider)) {
      final cam = ref.read(navigationCameraControllerProvider);
      if (cam.mode == CameraMode.awaitingFirstFix) {
        await _activateFollowingCamera(uloc);
      }
      return;
    }
    if (_browseAutocentered) return;
    final controller = _mapController;
    if (controller == null) return;
    _browseAutocentered = true;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(uloc.lat, uloc.lng), 16),
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
    // Prefer the live MapLibre fix (same source as the blue dot, written by
    // onUserLocationUpdated). Fall back to Geolocator's cache only if MapLibre
    // hasn't emitted yet — its cache can lag behind by 20-30m at cycling speed.
    UserLocation? initial = ref.read(userLocationProvider);
    if (initial == null) {
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) initial = positionToUserLocation(pos);
      } catch (_) {}
    }
    try {
      await service.start(
        origin: WaypointInput(lat: origin.lat, lng: origin.lng),
        destination:
            WaypointInput(lat: destination.lat, lng: destination.lng),
        initialLocation: initial,
      );
      if (mounted) _speakNav(AppLocalizations.of(context)!.navTtsDeparting);
      if (initial != null) {
        // We already have a fix — skip awaitingFirstFix entirely. Without this
        // the camera waits for ferrostar to emit a `.navigating` state with
        // snapped_location, which won't happen until a stream tick arrives.
        await _activateFollowingCamera(initial);
      }
    } catch (e, st) {
      reportError(e, st, context: 'nav.start');
    }
  }

  Future<void> _speakNav(String text) async {
    if (!ref.read(ttsEnabledProvider)) return;
    try {
      await ref.read(flutterTtsProvider).speak(text);
    } catch (e) {
      debugPrint('nav: tts error: $e');
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

  /// Transitions the camera into following mode for a nav session that has a
  /// known starting location. Idempotent: safe to call again on the first
  /// onUserLocationUpdated during nav as a fallback for the no-cache edge case.
  Future<void> _activateFollowingCamera(UserLocation loc) async {
    final cam = ref.read(navigationCameraControllerProvider);
    if (cam.mode != CameraMode.awaitingFirstFix) return;
    debugPrint('nav: activating following camera');
    AppHaptics.firstFix();
    cam.onNavStart();
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
    if (mounted) _speakNav(AppLocalizations.of(context)!.navTtsArrived);
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
    // Prefer ferrostar's snapped position so the camera lands on the route
    // line, not the raw fix. Fall back to the latest MapLibre fix when nav
    // hasn't produced a snapped state (e.g. before the first ferrostar tick).
    final snapped = ref.read(navigationStateProvider).value?.snappedLocation;
    final loc = snapped ?? ref.read(userLocationProvider);
    if (loc == null) return;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onRecenterTapped();
    await controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(loc.lat, loc.lng), cam.followZoom));
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
    final cached = ref.read(userLocationProvider);
    double? lat = cached?.lat;
    double? lng = cached?.lng;
    if (lat == null || lng == null) {
      try {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (e) {
        debugPrint('nav: refresh-preview GPS error: $e');
      }
    }
    if (!mounted || lat == null || lng == null) return;
    final l10n = AppLocalizations.of(context)!;
    ref.read(routeControllerProvider.notifier).setOrigin(
          Location(
            id: 'gps',
            name: l10n.locationCurrent,
            label: l10n.locationCurrent,
            lat: lat,
            lng: lng,
          ),
        );
  }

  /// Resolves a "current location" Location for use as a route origin. Prefers
  /// the cached MapLibre fix (live, written from onUserLocationUpdated), then
  /// Geolocator's last-known/current, and finally a Berlin-center fallback.
  Future<Location> _resolveCurrentOriginLocation(AppLocalizations l10n) async {
    final cached = ref.read(userLocationProvider);
    if (cached != null) {
      return Location(
        id: 'gps',
        name: l10n.locationCurrent,
        label: l10n.locationCurrent,
        lat: cached.lat,
        lng: cached.lng,
      );
    }
    Position? pos;
    try {
      pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
    } catch (_) {}
    return Location(
      id: 'gps',
      name: l10n.locationCurrent,
      label: l10n.locationCurrent,
      lat: pos?.latitude ?? 52.5065,
      lng: pos?.longitude ?? 13.4533,
    );
  }

  Future<TapFeature?> _probeRatingFeature(LatLng coords) async {
    final controller = _mapController;
    if (controller == null) return null;
    try {
      final screen = await controller.toScreenLocation(coords);
      final point =
          math.Point<double>(screen.x.toDouble(), screen.y.toDouble());
      final features = await controller.queryRenderedFeatures(
        point,
        [RatingOverlay.fillLayerId],
        null,
      );
      if (features.isEmpty) return null;
      final feature = features.first as Map<String, dynamic>;
      final props = feature['properties'] as Map<String, dynamic>?;
      final geom = feature['geometry'] as Map<String, dynamic>?;
      final id = props?['id'];
      if (id is! int || geom == null) return null;
      return TapFeature(areaId: id, geometry: geom);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    // Detach rating + brush overlays before MapLibre tears down its surface
    // to avoid leaking sources/layers through hot restarts. `dispose` can't
    // be async; detaches are fire-and-forget and swallow errors from an
    // already-destroyed surface.
    final notifier = _ratingOverlayNotifier;
    if (notifier != null) unawaited(notifier.detach());
    final brush = _brushOverlay;
    if (brush != null) unawaited(brush.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Cache the notifier on first build so dispose() can call detach()
    // without touching `ref` after unmount.
    _ratingOverlayNotifier ??=
        ref.read(ratingOverlayControllerProvider.notifier);
    _brushNotifier ??= ref.read(brushControllerProvider.notifier);
    final routeState = ref.watch(routeControllerProvider);
    final preview = routeState.preview;
    final styleAsync = ref.watch(mapStyleProvider);
    final navActive = ref.watch(navigationSessionProvider);
    final paintMode = ref.watch(
      brushControllerProvider.select((s) => s.paintMode),
    );
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
    ref.listen<AsyncValue<void>>(rerouteSucceededProvider, (_, next) {
      if (next is AsyncData) {
        _speakNav(AppLocalizations.of(context)!.navTtsRerouted);
      }
    });
    ref.listen<bool>(navigationSessionProvider, (prev, next) {
      if (prev == next) return;
      if (next) {
        _brushNotifier?.forceOff();
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
            data: (style) => Listener(
              behavior: HitTestBehavior.translucent,
              // Track physical pointer-down count across the whole map,
              // independent of gesture-arena state. While the map is in
              // paint mode, a second finger landing cancels any in-flight
              // stroke and latches a "multi-touch dirty" flag so further
              // onPan* callbacks no-op until every finger has lifted.
              // Without this the stock PanGestureRecognizer keeps tracking
              // pointer #1 through a pinch/pan attempt and paints a line
              // the user didn't mean to draw.
              onPointerDown: (_) {
                _paintPointerCount++;
                if (_paintPointerCount >= 2 && paintMode) {
                  _paintMultiTouch = true;
                  _brushNotifier?.cancelStroke();
                }
              },
              onPointerUp: (_) {
                if (_paintPointerCount > 0) _paintPointerCount--;
                if (_paintPointerCount == 0) _paintMultiTouch = false;
              },
              onPointerCancel: (_) {
                if (_paintPointerCount > 0) _paintPointerCount--;
                if (_paintPointerCount == 0) _paintMultiTouch = false;
              },
              child: _PaintGestureWrap(
                enabled: paintMode,
                onPanStart: (latLng) {
                  if (_paintMultiTouch) return;
                  final b = _brushNotifier;
                  if (b == null) return;
                  b.startStroke(latLng);
                },
                onPanUpdate: (latLng) {
                  if (_paintMultiTouch) return;
                  final b = _brushNotifier;
                  final c = _mapController;
                  if (b == null || c == null) return;
                  final zoom = c.cameraPosition?.zoom ?? 14;
                  b.addPoint(latLng, zoom);
                },
                onPanEnd: () async {
                  if (_paintMultiTouch) {
                    _brushNotifier?.cancelStroke();
                    return;
                  }
                  final b = _brushNotifier;
                  if (b == null) return;
                  await b.endStroke();
                },
                onPanCancel: () {
                  _brushNotifier?.cancelStroke();
                },
                onLongPress: (latLng) async {
                  if (_paintMultiTouch) return;
                  final b = _brushNotifier;
                  if (b == null) return;
                  final feature = await _probeRatingFeature(latLng);
                  if (feature == null) return;
                  unawaited(AppHaptics.recolor());
                  await b.recolorFromLongPress(feature);
                },
                toLatLng: (p) async {
                  final c = _mapController;
                  if (c == null) return const LatLng(0, 0);
                  return c.toLatLng(p);
                },
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
                  trackCameraPosition: true,
                  scrollGesturesEnabled: !paintMode,
                  rotateGesturesEnabled: !paintMode,
                  tiltGesturesEnabled: !paintMode,
                  zoomGesturesEnabled: !paintMode,
                  // Hide built-in compass + attribution chrome. Compass is
                  // redrawn inline above each RecenterFab (CompassFabInline);
                  // attribution is inlined under each sheet's CTA.
                  compassEnabled: false,
                  attributionButtonMargins: const math.Point(-1000, -1000),
                  // Non-paint mode: EagerGestureRecognizer so the map claims
                  // every pointer event (pan/pinch/rotate) when wrapped in a
                  // Scaffold that otherwise wins the gesture arena on iOS.
                  //
                  // Paint mode: empty set so pointers fall through to the
                  // outer RawGestureDetector (paint strokes). Map pans/zooms
                  // are already disabled via the *GesturesEnabled bools
                  // above, so the canvas stays static while painting.
                  gestureRecognizers: paintMode
                      ? const <Factory<OneSequenceGestureRecognizer>>{}
                      : <Factory<OneSequenceGestureRecognizer>>{
                          Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                          ),
                        },
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onUserLocationUpdated: _onUserLocationUpdated,
                  onStyleLoadedCallback: () async {
                    // Attach rating overlay AFTER style is loaded — MapLibre
                    // silently ignores addGeoJsonSource / addLayer calls
                    // made before the style is ready. Route line and markers
                    // are added later via the annotation APIs and sit above
                    // all custom style layers by default, so the overlay
                    // stays visually below them. `attachToMap` is idempotent
                    // in case the style reloads.
                    final c = _mapController;
                    if (c == null) return;
                    await ref
                        .read(ratingOverlayControllerProvider.notifier)
                        .attachToMap(c);
                    _brushOverlay?.detach();
                    _brushOverlay = await BrushOverlay.attach(c);
                    _brushNotifier?.attach(surface: _brushOverlay!);
                    _updateHomeMarker(
                        ref.read(homeLocationProvider).valueOrNull);
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
            ),
          ),
          if (!navActive)
            AnimatedSlide(
              offset: paintMode ? const Offset(0, -3) : Offset.zero,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: RouteCard(),
                ),
              ),
            ),
          if (navActive)
            NavTopBar(
              ttsEnabled: ref.watch(ttsEnabledProvider),
              rerouting: _rerouting,
              onToggleTts: () => ref
                  .read(ttsEnabledProvider.notifier)
                  .update((v) => !v),
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
                : paintMode
                    ? const _PaintSheetWrapper(key: ValueKey('paint'))
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

// ---------------------------------------------------------------------------
// Paint-mode FAB column: undo + redo on top, then the brush toggle. Used by
// the paint sheet wrapper only; home/route sheets render their own column
// without undo/redo via HomeSheetContainer / RouteSheet.
// ---------------------------------------------------------------------------

class _PaintFabColumn extends ConsumerWidget {
  const _PaintFabColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brush = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _UndoRedoFab(
          tooltip: l10n.paintUndo,
          keyValue: 'undo-fab',
          icon: Icons.undo,
          enabled: brush.canUndo && !brush.busy,
          loading: brush.activeOp == BrushOp.undo,
          onPressed: notifier.undo,
        ),
        const SizedBox(height: 8),
        _UndoRedoFab(
          tooltip: l10n.paintRedo,
          keyValue: 'redo-fab',
          icon: Icons.redo,
          enabled: brush.canRedo && !brush.busy,
          loading: brush.activeOp == BrushOp.redo,
          onPressed: notifier.redo,
        ),
        const SizedBox(height: 12),
        const BrushFab(),
      ],
    );
  }
}

class _UndoRedoFab extends StatelessWidget {
  const _UndoRedoFab({
    required this.tooltip,
    required this.keyValue,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String tooltip;
  final String keyValue;
  final IconData icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final active = enabled || loading;
    final bg = active ? BbbColors.panel : BbbColors.bgAlt;
    final fg = active ? BbbColors.ink : BbbColors.inkFaint;
    return Tooltip(
      message: tooltip,
      child: Material(
        key: ValueKey(keyValue),
        shape: const CircleBorder(),
        elevation: 0,
        color: bg,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: BbbShadow.sm,
            ),
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    )
                  : Icon(icon, color: fg, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paint sheet wrapper — stacks the paint FAB column above the PaintSheet
// body so undo/redo, compass, and the brush toggle stay visible while color
// chips are open.
// ---------------------------------------------------------------------------

class _PaintSheetWrapper extends StatelessWidget {
  const _PaintSheetWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 16, 8),
            child: _PaintFabColumn(),
          ),
          PaintSheet(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paint-mode gesture wrapper. When [enabled], intercepts single-pointer
// pans (brush strokes) and single taps (recolor/erase existing polygons).
// When off, child receives all gestures as usual.
// ---------------------------------------------------------------------------

class _PaintGestureWrap extends StatelessWidget {
  const _PaintGestureWrap({
    required this.enabled,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.onPanCancel,
    required this.onLongPress,
    required this.toLatLng,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<LatLng> onPanStart;
  final ValueChanged<LatLng> onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;
  final ValueChanged<LatLng> onLongPress;
  final Future<LatLng> Function(math.Point<double>) toLatLng;
  final Widget child;

  math.Point<double> _point(Offset o) => math.Point(o.dx, o.dy);

  @override
  Widget build(BuildContext context) {
    // Always render RawGestureDetector so the widget tree shape stays stable
    // when `enabled` toggles. Reparenting MapLibreMap (by wrapping/unwrapping
    // it) disposes the underlying UiKitView — which blows away our rating
    // overlay layers until the next style reload. When disabled, we register
    // zero recognizers and fall through to the child.
    final gestures = enabled
        ? <Type, GestureRecognizerFactory>{
            PanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
              PanGestureRecognizer.new,
              (r) {
                // Report positions from the initial pointer-down event, not
                // from where slop was resolved. Without this the brush stroke
                // jumps ~18px away from the finger on touch-down.
                r.dragStartBehavior = DragStartBehavior.down;
                r.onStart = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onPanStart(latLng);
                };
                r.onUpdate = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onPanUpdate(latLng);
                };
                r.onEnd = (_) => onPanEnd();
                r.onCancel = onPanCancel;
              },
            ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 500),
              ),
              (r) {
                r.onLongPressStart = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onLongPress(latLng);
                };
              },
            ),
          }
        : const <Type, GestureRecognizerFactory>{};
    return RawGestureDetector(
      behavior: enabled ? HitTestBehavior.opaque : HitTestBehavior.translucent,
      gestures: gestures,
      child: child,
    );
  }
}
