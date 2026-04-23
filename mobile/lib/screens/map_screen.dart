import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' hide UserLocation;

import '../theme/tokens.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../models/route_preview.dart';
import '../models/route_state.dart';
import '../navigation/camera_controller.dart';
import '../navigation/location_converter.dart';
import '../navigation/maneuver_icons.dart';
import '../navigation/nav_constants.dart';
import '../providers/brush_provider.dart';
import '../providers/navigation_camera_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/navigation_session_provider.dart';
import '../providers/location_provider.dart';
import '../providers/map_bearing_provider.dart';
import '../providers/rating_overlay_provider.dart';
import '../providers/route_provider.dart';
import '../services/brush_overlay.dart';
import '../services/haptics.dart';
import '../services/map_style_loader.dart';
import '../services/rating_overlay.dart';
import '../services/route_drawing.dart';
import '../widgets/arrived_sheet.dart';
import '../widgets/brush_fab.dart';
import '../widgets/eta_sheet.dart';
import '../widgets/home_sheet.dart';
import '../widgets/paint_pan_recognizer.dart';
import '../widgets/paint_sheet.dart';
import '../widgets/recenter_fab.dart';
import '../widgets/rerouting_toast.dart';
import '../widgets/route_card.dart';
import '../widgets/route_summary.dart';
import '../widgets/tts_toggle_fab.dart';
import '../widgets/turn_banner.dart';

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
  Symbol? _homeMarker;
  RatingOverlayController? _ratingOverlayNotifier;
  BrushOverlay? _brushOverlay;
  BrushController? _brushNotifier;
  bool _ttsEnabled = true;
  bool _rerouting = false;
  bool _browseAutocentered = false;
  double? _lastLoggedZoom;
  double? _pinchStartZoom;
  double? _pinchLastZoom;

  Future<void> _handleMapTap(math.Point<double> point, LatLng coords) async {
    if (ref.read(navigationSessionProvider)) return;
    if (ref.read(brushControllerProvider).paintMode) return;
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

  static Future<Uint8List> _createHomeMarkerImage() async {
    const double size = 52;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = const Color(0xFF3B82F6),
    );
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(Icons.home.codePoint),
        style: TextStyle(
          fontSize: size * 0.72,
          fontFamily: Icons.home.fontFamily,
          package: Icons.home.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _updateHomeMarker(Location? home) async {
    final controller = _mapController;
    if (controller == null) return;
    final existing = _homeMarker;
    if (existing != null) {
      await controller.removeSymbol(existing);
      _homeMarker = null;
    }
    if (home != null) {
      await controller.addImage('home-marker', await _createHomeMarkerImage());
      _homeMarker = await controller.addSymbol(SymbolOptions(
        geometry: LatLng(home.lat, home.lng),
        iconImage: 'home-marker',
        iconSize: 1.0,
        iconAnchor: 'center',
      ));
    }
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
            data: (style) => _PaintGestureWrap(
              enabled: paintMode,
              onPanStart: (latLng) {
                final b = _brushNotifier;
                if (b == null) return;
                b.startStroke(latLng);
              },
              onPanUpdate: (latLng) {
                final b = _brushNotifier;
                final c = _mapController;
                if (b == null || c == null) return;
                final zoom = c.cameraPosition?.zoom ?? 14;
                b.addPoint(latLng, zoom);
              },
              onPanEnd: () async {
                final b = _brushNotifier;
                if (b == null) return;
                await b.endStroke(tapFeatureLookup: _probeRatingFeature);
              },
              onPanCancel: () {
                _brushNotifier?.cancelStroke();
              },
              onTap: (latLng) async {
                final b = _brushNotifier;
                if (b == null) return;
                b.startStroke(latLng);
                await b.endStroke(tapFeatureLookup: _probeRatingFeature);
              },
              onScaleStart: (_) {
                final c = _mapController;
                if (c == null) return;
                final z = c.cameraPosition?.zoom ?? 14;
                _pinchStartZoom = z;
                _pinchLastZoom = z;
                _brushNotifier?.cancelStroke();
              },
              onScaleUpdate: (details) {
                final c = _mapController;
                final start = _pinchStartZoom;
                final last = _pinchLastZoom;
                if (c == null || start == null || last == null) return;
                if (details.scale <= 0) return;
                final newZoom = start + math.log(details.scale) / math.ln2;
                final delta = newZoom - last;
                _pinchLastZoom = newZoom;
                c.moveCamera(
                  CameraUpdate.zoomBy(delta, details.localFocalPoint),
                );
                final pan = details.focalPointDelta;
                if (pan != Offset.zero) {
                  c.moveCamera(CameraUpdate.scrollBy(-pan.dx, -pan.dy));
                }
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
                // redrawn inline above each RecenterFab (_CompassFabInline);
                // attribution is inlined under each sheet's CTA.
                compassEnabled: false,
                attributionButtonMargins: const math.Point(-1000, -1000),
                // Non-paint mode: EagerGestureRecognizer so the map claims
                // every pointer event (pan/pinch/rotate) when wrapped in a
                // Scaffold that otherwise wins the gesture arena on iOS.
                //
                // Paint mode: empty set so no platform-view recognizer joins
                // the Flutter arena. Any recognizer added here also claims
                // single-pointer events via `startTrackingPointer` in its
                // `addAllowedPointer`, which blocks the outer
                // PaintPanGestureRecognizer from winning single-finger
                // arenas. Instead, pinch is driven manually from the outer
                // RawGestureDetector's MultiPointerScaleGestureRecognizer.
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
                onUserLocationUpdated: (loc) => _handleBrowseLocationUpdate(
                    loc.position.latitude, loc.position.longitude),
                onStyleLoadedCallback: () async {
                  // Attach rating overlay AFTER style is loaded — MapLibre
                  // silently ignores addGeoJsonSource / addLayer calls made
                  // before the style is ready. Route line and markers are
                  // added later via the annotation APIs and sit above all
                  // custom style layers by default, so the overlay stays
                  // visually below them. `attachToMap` is idempotent in case
                  // the style reloads.
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
                    if (_lastLoggedZoom == null ||
                        (zoom - _lastLoggedZoom!).abs() >= 0.01) {
                      debugPrint('zoom: ${zoom.toStringAsFixed(2)}');
                      _lastLoggedZoom = zoom;
                    }
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
          if (!navActive)
            const SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: RouteCard(),
              ),
            ),
          if (navActive)
            _NavTopBar(
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
                ? _NavigationSheet(
                    key: const ValueKey('nav'),
                    onClose: () =>
                        ref.read(navigationSessionProvider.notifier).state =
                            false,
                  )
                : paintMode
                    ? _PaintSheetWrapper(
                        key: const ValueKey('paint'),
                        onFlyToMyLocation: _flyToCurrentLocation,
                        onResetBearing: _resetBearingToNorth,
                      )
                    : routeActive
                        ? _RouteSheet(
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
                        : _HomeSheet(
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
// Home sheet wrapper — hosts the HomeSheet widget plus a recenter FAB whose
// vertical position tracks the sheet's current snap size.
// ---------------------------------------------------------------------------

class _HomeSheet extends ConsumerStatefulWidget {
  const _HomeSheet({
    super.key,
    required this.onFlyToMyLocation,
    required this.onResetBearing,
    required this.onNavigateHome,
  });

  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;
  final VoidCallback onNavigateHome;

  @override
  ConsumerState<_HomeSheet> createState() => _HomeSheetState();
}

class _HomeSheetState extends ConsumerState<_HomeSheet> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, _) {
            final size =
                _sheetController.isAttached ? _sheetController.size : 0.16;
            final sheetPx = size * mq.size.height;
            return Positioned(
              right: 16,
              bottom: sheetPx + 8,
              child: _MapFabColumn(
                onFlyToMyLocation: widget.onFlyToMyLocation,
                onResetBearing: widget.onResetBearing,
              ),
            );
          },
        ),
        HomeSheet(
          onNavigateHome: widget.onNavigateHome,
          sheetController: _sheetController,
        ),
      ],
    );
  }
}

class _RecenterCircleFab extends StatefulWidget {
  const _RecenterCircleFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RecenterCircleFab> createState() => _RecenterCircleFabState();
}

class _RecenterCircleFabState extends State<_RecenterCircleFab>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1.0,
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _pressed = false);
    widget.onTap();
    _flash.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        // color: BbbColors.panel,
        // surfaceTintColor: BbbColors.panel,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: BbbColors.panel,
              shape: BoxShape.circle,
              boxShadow: BbbShadow.sm,
            ),
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final color = Color.lerp(
                  BbbColors.brand,
                  BbbColors.inkMuted,
                  Curves.easeOut.transform(_flash.value),
                )!;
                return Icon(Icons.my_location, color: color, size: 22);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compass + attribution — replace MapLibre's built-in chrome.
// ---------------------------------------------------------------------------

/// Inline compass that sits above a RecenterFab in each sheet. Reads
/// the map bearing from [mapBearingProvider] and renders nothing when
/// the map is ~north-up; otherwise shows a rotated glyph + spacer,
/// tapping animates the map back to bearing 0.
class _CompassFabInline extends ConsumerWidget {
  const _CompassFabInline({required this.onResetBearing});

  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bearing = ref.watch(mapBearingProvider);
    if (bearing.abs() <= 0.5) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Tooltip(
        message: l10n.mapResetNorth,
        child: Material(
          shape: const CircleBorder(),
          color: BbbColors.panel,
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onResetBearing,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: BbbColors.panel,
                shape: BoxShape.circle,
                boxShadow: BbbShadow.sm,
              ),
              child: Transform.rotate(
                angle: -bearing * math.pi / 180,
                child: const Icon(
                  Icons.navigation,
                  size: 22,
                  color: BbbColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Shared right-side FAB column — rendered by every non-nav sheet. Order from
// top to bottom: undo, redo (paint mode only), compass (when bearing ≠ 0),
// recenter, brush. Brush sits at the bottom so it stays at a predictable spot
// as the column above it grows or shrinks.
// ---------------------------------------------------------------------------

class _MapFabColumn extends ConsumerWidget {
  const _MapFabColumn({
    required this.onFlyToMyLocation,
    required this.onResetBearing,
  });

  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brush = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (brush.paintMode) ...[
          Tooltip(
            message: l10n.paintUndo,
            child: FloatingActionButton.small(
              key: const ValueKey('undo-fab'),
              heroTag: 'brush-undo-fab',
              onPressed: brush.canUndo ? notifier.undo : null,
              backgroundColor:
                  brush.canUndo ? BbbColors.panel : BbbColors.bgAlt,
              foregroundColor:
                  brush.canUndo ? BbbColors.ink : BbbColors.inkFaint,
              child: const Icon(Icons.undo),
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: l10n.paintRedo,
            child: FloatingActionButton.small(
              key: const ValueKey('redo-fab'),
              heroTag: 'brush-redo-fab',
              onPressed: brush.canRedo ? notifier.redo : null,
              backgroundColor:
                  brush.canRedo ? BbbColors.panel : BbbColors.bgAlt,
              foregroundColor:
                  brush.canRedo ? BbbColors.ink : BbbColors.inkFaint,
              child: const Icon(Icons.redo),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _CompassFabInline(onResetBearing: onResetBearing),
        _RecenterCircleFab(onTap: onFlyToMyLocation),
        const SizedBox(height: 12),
        const BrushFab(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Paint sheet wrapper — stacks the shared FAB column above the PaintSheet
// body so the brush FAB, undo/redo, and recenter controls stay visible while
// color chips are open.
// ---------------------------------------------------------------------------

class _PaintSheetWrapper extends StatelessWidget {
  const _PaintSheetWrapper({
    super.key,
    required this.onFlyToMyLocation,
    required this.onResetBearing,
  });

  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
            child: _MapFabColumn(
              onFlyToMyLocation: onFlyToMyLocation,
              onResetBearing: onResetBearing,
            ),
          ),
          const PaintSheet(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route sheet — slides up over home sheet when a route is active (loading,
// error, or preview ready). Fixed height; not draggable.
// ---------------------------------------------------------------------------

class _RouteSheet extends ConsumerWidget {
  const _RouteSheet({
    super.key,
    required this.routeState,
    required this.preview,
    required this.onFlyToMyLocation,
    required this.onResetBearing,
    required this.onStart,
  });

  final RouteState routeState;
  final RoutePreview? preview;
  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
            child: _MapFabColumn(
              onFlyToMyLocation: onFlyToMyLocation,
              onResetBearing: onResetBearing,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            decoration: const BoxDecoration(
              color: BbbColors.panel,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
              boxShadow: BbbShadow.panel,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (routeState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (routeState.error != null)
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(l10n.routeLoadError,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(routeControllerProvider.notifier)
                              .clear(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
                  else if (preview != null)
                    RouteSummary(
                      durationMinutes: (preview!.time / 60000).round(),
                      distanceKm: preview!.distance / 1000,
                      onStart: onStart,
                      onClose: () {
                        ref.read(routeControllerProvider.notifier).clear();
                        onFlyToMyLocation();
                      },
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

// ---------------------------------------------------------------------------
// Navigation sheet — slides up over route sheet during active navigation.
// Fixed height; not draggable.
// ---------------------------------------------------------------------------

class _NavigationSheet extends ConsumerWidget {
  const _NavigationSheet({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(navigationStateProvider);
    final cam = ref.watch(navigationCameraControllerProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: BbbColors.panel,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
          boxShadow: BbbShadow.panel,
        ),
        child: SafeArea(
          top: false,
          child: cam.mode == CameraMode.arrived
              ? ArrivedSheet(onDone: onClose)
              : EtaSheet(
                  navState: navState,
                  onClose: onClose,
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav top bar — TurnBanner + RecenterFab, shown during navigation above
// the navigation sheet.
// ---------------------------------------------------------------------------

class _NavTopBar extends ConsumerWidget {
  const _NavTopBar({
    required this.ttsEnabled,
    required this.rerouting,
    required this.onToggleTts,
    required this.onRecenter,
    required this.onResetBearing,
  });

  final bool ttsEnabled;
  final bool rerouting;
  final VoidCallback onToggleTts;
  final VoidCallback onRecenter;
  final VoidCallback onResetBearing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final navState = ref.watch(navigationStateProvider);
    final cam = ref.watch(navigationCameraControllerProvider);

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                navState.when(
                  loading: () => TurnBanner(
                    primaryText: l10n.navStarting,
                    distanceText: '',
                  ),
                  error: (e, _) => TurnBanner(
                    primaryText: l10n.navError,
                    distanceText: '',
                    icon: Icons.error_outline,
                  ),
                  data: (state) => TurnBanner(
                    primaryText:
                        state.currentVisual?.primaryText ?? l10n.navOnRoute,
                    distanceText: state.progress != null
                        ? formatDistance(
                            state.progress!.distanceToNextManeuverM)
                        : '',
                    icon: state.currentVisual != null
                        ? iconForManeuver(
                            state.currentVisual!.maneuverType,
                            state.currentVisual!.maneuverModifier,
                          )
                        : Icons.straight,
                  ),
                ),
                if (rerouting) const ReroutingToast(),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.only(right: 16, bottom: kEtaSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TtsToggleFab(enabled: ttsEnabled, onTap: onToggleTts),
                  if (cam.mode == CameraMode.free) ...[
                    const SizedBox(height: 12),
                    _CompassFabInline(onResetBearing: onResetBearing),
                    RecenterFab(onTap: onRecenter),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
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
    required this.onTap,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.toLatLng,
    required this.child,
  });

  final bool enabled;
  final ValueChanged<LatLng> onPanStart;
  final ValueChanged<LatLng> onPanUpdate;
  final VoidCallback onPanEnd;
  final VoidCallback onPanCancel;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<ScaleStartDetails> onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
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
            PaintPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    PaintPanGestureRecognizer>(
              PaintPanGestureRecognizer.new,
              (r) {
                r.onStart = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onPanStart(latLng);
                };
                r.onUpdate = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onPanUpdate(latLng);
                };
                r.onEnd = (_) => onPanEnd();
                // Fires when the arena rejects us after onStart fired — i.e.
                // a second pointer landed mid-stroke and we released the
                // gesture to the map's ScaleGestureRecognizer.
                r.onCancel = onPanCancel;
              },
            ),
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (r) {
                r.onTapUp = (d) async {
                  final latLng = await toLatLng(_point(d.localPosition));
                  onTap(latLng);
                };
              },
            ),
            MultiPointerScaleGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                    MultiPointerScaleGestureRecognizer>(
              MultiPointerScaleGestureRecognizer.new,
              (r) {
                r.onStart = onScaleStart;
                r.onUpdate = onScaleUpdate;
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
