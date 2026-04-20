import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/ratings_api.dart';
import '../models/user.dart';
import '../services/rating_fetch_policy.dart';
import '../services/rating_overlay.dart';
import 'auth_provider.dart';

/// Snapshot of the map camera needed to decide whether to refetch the
/// rating overlay. Pulled by the caller (usually a wrapper around a live
/// `MapLibreMapController`) and handed to the controller so the controller
/// itself stays unaware of MapLibre.
class CameraState {
  const CameraState({required this.zoom, required this.viewport});
  final double zoom;
  final Bbox viewport;
}

/// Async function that returns the current camera state, or null when it
/// can't be read (e.g. the map hasn't finished its first layout).
typedef CameraProbe = Future<CameraState?> Function();

/// Async function that builds and attaches a [RatingOverlaySurface]. Called
/// once from [RatingOverlayController.attach]; allowed to throw if the
/// underlying style isn't ready — the controller logs and bails.
typedef OverlayAttacher = Future<RatingOverlaySurface> Function();

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Coordinates fetching the user's rating polygons and updating the
/// [RatingOverlaySurface] render state. Holds no direct reference to
/// MapLibre — the caller supplies a [CameraProbe] and [OverlayAttacher],
/// which keeps the controller testable with pure Dart fakes.
///
/// Lifecycle:
///   1. `onStyleLoadedCallback`: call [attach] with probe + attacher (see
///      [RatingOverlayControllerMap.attachToMap] for the MapLibre adapter).
///   2. `onCameraIdle`: call [onCameraIdle].
///   3. Auth changes: the controller itself watches [authControllerProvider]
///      and clears the overlay on login/logout.
///   4. Screen disposed: call [detach] (Riverpod auto-disposes the notifier).
class RatingOverlayController extends Notifier<void> {
  RatingOverlaySurface? _overlay;
  CameraProbe? _cameraProbe;
  Bbox? _lastFetched;
  CancelToken? _inFlight;

  @override
  void build() {
    ref.onDispose(() {
      _inFlight?.cancel();
    });
  }

  /// Attach the overlay. Idempotent — a second call while already attached
  /// is a no-op, which matters because MapLibre's `onStyleLoadedCallback`
  /// can fire more than once (style reload on theme change, retry, etc.).
  Future<void> attach({
    required CameraProbe cameraProbe,
    required OverlayAttacher attachOverlay,
  }) async {
    if (_overlay != null) {
      _log('rating-overlay: attach skipped (already attached)');
      return;
    }
    _log('rating-overlay: attach start');
    _cameraProbe = cameraProbe;
    try {
      _overlay = await attachOverlay();
      _log('rating-overlay: attach ok');
    } catch (e, st) {
      _log('rating-overlay: attach FAILED: $e\n$st');
      _cameraProbe = null;
      return;
    }
    // Wire up auth *after* a successful attach so we react to login/logout
    // without leaking a listener on a half-initialized overlay.
    ref.listen<AsyncValue<User?>>(authControllerProvider, (prev, next) {
      final prevId = prev?.value?.id;
      final nextId = next.value?.id;
      _log('rating-overlay: auth change $prevId -> $nextId');
      if (prevId != nextId) {
        _lastFetched = null;
        _overlay?.clear();
        if (nextId != null) _evaluateAndFetch();
      }
    });
    // Kick off an initial fetch only if auth is already resolved. If it's
    // still loading the listener above handles the first transition, which
    // avoids a double-fetch on cold start.
    if (ref.read(authControllerProvider).value != null) {
      _evaluateAndFetch();
    }
  }

  /// Detach the overlay and cancel any pending work. Safe to call multiple
  /// times.
  Future<void> detach() async {
    _inFlight?.cancel();
    _inFlight = null;
    final overlay = _overlay;
    _overlay = null;
    _cameraProbe = null;
    _lastFetched = null;
    await overlay?.detach();
  }

  /// Hook for `MapLibreMap.onCameraIdle`. Evaluates the fetch policy and
  /// refreshes the overlay if needed. No-op until [attach] has wired up
  /// the camera probe and overlay.
  ///
  /// Camera-idle already acts as a natural debouncer — MapLibre only fires
  /// it once the user stops panning/zooming — so we evaluate synchronously
  /// and rely on [decideFetch] + [CancelToken] to drop redundant requests.
  void onCameraIdle() {
    if (_overlay == null || _cameraProbe == null) return;
    _evaluateAndFetch();
  }

  Future<void> _evaluateAndFetch() async {
    final overlay = _overlay;
    final probe = _cameraProbe;
    if (overlay == null || probe == null) {
      _log('rating-overlay: eval skip (detached)');
      return;
    }

    final camera = await probe();
    if (camera == null) {
      _log('rating-overlay: eval skip (no camera state)');
      return;
    }

    final decision = decideFetch(
      zoom: camera.zoom,
      viewport: camera.viewport,
      lastFetched: _lastFetched,
    );
    _log('rating-overlay: eval zoom=${camera.zoom} '
        'viewport=${camera.viewport.toQueryString()} '
        'fetch=${decision.shouldFetch}');
    if (!decision.shouldFetch) return;

    // Cancel any previous request — we only care about the latest viewport.
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;

    final fetchBbox = decision.fetchBbox!;
    try {
      final api = ref.read(ratingsApiProvider);
      final data = await api.getOverlay(
        fetchBbox.toQueryString(),
        cancelToken: token,
      );
      if (token.isCancelled) return;
      final features = data['features'] as List<dynamic>? ?? const [];
      _log('rating-overlay: fetch ok, features=${features.length}');
      await overlay.update(data);
      _lastFetched = fetchBbox;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _log('rating-overlay: fetch failed status=${e.response?.statusCode} '
          'type=${e.type} msg=${e.message}');
    } catch (e) {
      _log('rating-overlay: fetch failed: $e');
    } finally {
      if (identical(_inFlight, token)) {
        _inFlight = null;
      }
    }
  }
}

/// Convenience adapter that bridges [RatingOverlayController.attach] to a
/// live `MapLibreMapController`. Lives here (not on the controller) so the
/// controller itself stays free of MapLibre imports used only for this glue.
extension RatingOverlayControllerMap on RatingOverlayController {
  /// Attach against a real MapLibre controller. [belowLayerId] is forwarded
  /// to [RatingOverlay.attach] so the caller can keep other overlays (route
  /// line, markers) rendered on top.
  Future<void> attachToMap(
    MapLibreMapController controller, {
    String? belowLayerId,
  }) {
    return attach(
      cameraProbe: () async {
        final zoom = controller.cameraPosition?.zoom;
        if (zoom == null) return null;
        try {
          final visible = await controller.getVisibleRegion();
          return CameraState(
            zoom: zoom,
            viewport: Bbox.fromLatLngBounds(visible),
          );
        } catch (e) {
          _log('rating-overlay: getVisibleRegion failed: $e');
          return null;
        }
      },
      attachOverlay: () =>
          RatingOverlay.attach(controller, belowLayerId: belowLayerId),
    );
  }
}

final ratingOverlayControllerProvider =
    NotifierProvider<RatingOverlayController, void>(
        RatingOverlayController.new);
