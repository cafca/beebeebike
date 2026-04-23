import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../api/ratings_api.dart';
import '../app.dart';
import '../config/berlin_bounds.dart';
import '../models/user.dart';
import '../services/rating_events_client.dart';
import '../services/rating_overlay.dart';
import 'auth_provider.dart';

/// Async function that builds and attaches a [RatingOverlaySurface]. Called
/// once from [RatingOverlayController.attach]; allowed to throw if the
/// underlying style isn't ready — the controller logs and bails.
typedef OverlayAttacher = Future<RatingOverlaySurface> Function();

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Observable state for [RatingOverlayController]. Kept minimal — the only
/// UI-relevant bit today is whether live sync is degraded, which drives a
/// one-shot toast in the map screen.
@immutable
class RatingOverlayState {
  const RatingOverlayState({this.liveSyncDegraded = false});
  final bool liveSyncDegraded;

  RatingOverlayState copyWith({bool? liveSyncDegraded}) => RatingOverlayState(
        liveSyncDegraded: liveSyncDegraded ?? this.liveSyncDegraded,
      );
}

/// Coordinates the user's rating polygons.
///
/// Sync model:
///   - One full fetch over [kBerlinSyncBbox] on attach (when auth is ready)
///     and on every auth transition to a logged-in user.
///   - Subsequent updates arrive via SSE ([RatingEventsClient]); every
///     `invalidate` (including reconnects) triggers a fresh full fetch.
///   - No camera-idle polling. Panning/zooming never hits the network.
///
/// If SSE is disabled (server 404 or client config flag off) the overlay
/// stays whatever it was at the last full fetch until the next app start.
/// [RatingOverlayState.liveSyncDegraded] flips true in that case so the UI
/// can surface a toast.
class RatingOverlayController extends Notifier<RatingOverlayState> {
  RatingOverlaySurface? _overlay;
  CancelToken? _inFlight;
  RatingEventsClient? _eventsClient;

  @override
  RatingOverlayState build() {
    ref.onDispose(() {
      _inFlight?.cancel();
      unawaited(_eventsClient?.stop());
      _eventsClient = null;
    });
    return const RatingOverlayState();
  }

  /// Attach the overlay. Idempotent — a second call while already attached
  /// is a no-op, which matters because MapLibre's `onStyleLoadedCallback`
  /// can fire more than once (style reload on theme change, retry, etc.).
  Future<void> attach({required OverlayAttacher attachOverlay}) async {
    if (_overlay != null) {
      _log('rating-overlay: attach skipped (already attached)');
      return;
    }
    _log('rating-overlay: attach start');
    try {
      _overlay = await attachOverlay();
      _log('rating-overlay: attach ok');
    } catch (e, st) {
      _log('rating-overlay: attach FAILED: $e\n$st');
      return;
    }
    // Wire up auth *after* a successful attach so we react to login/logout
    // without leaking a listener on a half-initialized overlay.
    ref.listen<AsyncValue<User?>>(authControllerProvider, (prev, next) {
      // `valueOrNull` instead of `.value`: the latter rethrows when the
      // state is `AsyncError` (e.g. anonymous-auth connection refused in
      // CI integration tests), which would crash the whole listener.
      final prevId = prev?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      _log('rating-overlay: auth change $prevId -> $nextId');
      if (prevId != nextId) {
        _overlay?.clear();
        // Restart the SSE stream against the new session cookie so
        // invalidations are filtered for the right user. The client is
        // keyed to a Dio instance, not a user id, so stopping and starting
        // is cheap — it just drops the held socket.
        unawaited(_restartEventsClient());
        if (nextId != null) _fullSync();
      }
    });
    // Kick off an initial fetch only if auth is already resolved. If it's
    // still loading the listener above handles the first transition, which
    // avoids a double-fetch on cold start. Use `valueOrNull` — plain
    // `.value` rethrows on `AsyncError`, which happens in CI integration
    // tests where anonymous-auth gets "connection refused".
    if (ref.read(authControllerProvider).valueOrNull != null) {
      _fullSync();
      _startEventsClient();
    }
  }

  /// Spin up the rating-change SSE listener if:
  ///   - the client-side kill switch ([AppConfig.ratingsSseEnabled]) is on,
  ///   - auth has resolved,
  ///   - the overlay is currently attached.
  ///
  /// Called during [attach] and on every auth transition. Safe to call
  /// multiple times — [RatingEventsClient.start] is idempotent.
  void _startEventsClient() {
    if (_overlay == null) return;
    final config = ref.read(appConfigProvider);
    if (!config.ratingsSseEnabled) {
      _log('rating-overlay: SSE disabled via client config');
      _markLiveSyncDegraded();
      return;
    }
    // `valueOrNull`: `.value` rethrows on `AsyncError` (CI integration tests
    // hit "connection refused" on anonymous auth), which would crash attach.
    if (ref.read(authControllerProvider).valueOrNull == null) return;
    _eventsClient ??= ref.read(ratingEventsClientFactoryProvider)(
      _onInvalidate,
      onServerDisabled: _markLiveSyncDegraded,
    );
    _eventsClient!.start();
  }

  Future<void> _restartEventsClient() async {
    final existing = _eventsClient;
    _eventsClient = null;
    if (existing != null) {
      await existing.stop();
    }
    _startEventsClient();
  }

  /// Invoked by [RatingEventsClient] when the backend signals that the
  /// user's painted areas changed (or when the SSE stream reconnects —
  /// which triggers a forced invalidate as a missed-event hedge; see
  /// [RatingEventsClient]). Every invalidate triggers one full sync.
  void _onInvalidate() {
    _log('rating-overlay: invalidate from server');
    _fullSync();
  }

  void _markLiveSyncDegraded() {
    if (state.liveSyncDegraded) return;
    state = state.copyWith(liveSyncDegraded: true);
  }

  /// Detach the overlay and cancel any pending work. Safe to call multiple
  /// times.
  Future<void> detach() async {
    _inFlight?.cancel();
    _inFlight = null;
    final client = _eventsClient;
    _eventsClient = null;
    final overlay = _overlay;
    _overlay = null;
    await client?.stop();
    await overlay?.detach();
  }

  /// Trigger an immediate full sync. Called by brush after a successful
  /// paint so the overlay reflects the user's own change without waiting
  /// for the SSE roundtrip.
  Future<void> refreshAfterPaint() => _fullSync();

  Future<void> _fullSync() async {
    final overlay = _overlay;
    if (overlay == null) {
      _log('rating-overlay: sync skip (detached)');
      return;
    }
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;
    try {
      final api = ref.read(ratingsApiProvider);
      final data = await api.getOverlay(
        kBerlinSyncBbox.toQueryString(),
        cancelToken: token,
      );
      if (token.isCancelled) return;
      final features = data['features'] as List<dynamic>? ?? const [];
      _log('rating-overlay: sync ok, features=${features.length}');
      await overlay.update(data);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _log('rating-overlay: sync failed status=${e.response?.statusCode} '
          'type=${e.type} msg=${e.message}');
    } catch (e) {
      _log('rating-overlay: sync failed: $e');
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
  Future<void> attachToMap(
    MapLibreMapController controller, {
    String? belowLayerId,
  }) {
    return attach(
      attachOverlay: () =>
          RatingOverlay.attach(controller, belowLayerId: belowLayerId),
    );
  }
}

final ratingOverlayControllerProvider =
    NotifierProvider<RatingOverlayController, RatingOverlayState>(
        RatingOverlayController.new);
