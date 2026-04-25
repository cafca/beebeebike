import 'dart:async';

import 'package:beebeebike/api/ratings_api.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart' show AppConfig;
import 'package:beebeebike/config/berlin_bounds.dart';
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/services/error_reporter.dart';
import 'package:beebeebike/services/rating_events_client.dart';
import 'package:beebeebike/services/rating_overlay.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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
  bool _authListenerWired = false;
  Map<String, dynamic>? _lastCollection;

  @override
  RatingOverlayState build() {
    ref.onDispose(() {
      _inFlight?.cancel();
      unawaited(_eventsClient?.stop());
      _eventsClient = null;
    });
    return const RatingOverlayState();
  }

  /// Attach the overlay to the current MapLibre style.
  ///
  /// Called from `onStyleLoadedCallback`, which fires on first style load
  /// and on every subsequent style reload — including MapLibre platform-view
  /// recreation triggered by our paint-mode `gestureRecognizers` toggle.
  /// The prior overlay reference points at a dead native view in that case,
  /// so we unconditionally detach it and attach fresh layers to the new
  /// style. Auth wiring runs once per controller lifetime.
  Future<void> attach({required OverlayAttacher attachOverlay}) async {
    final prior = _overlay;
    _overlay = null;
    if (prior != null) {
      _log('rating-overlay: reattaching (prior overlay discarded)');
      try {
        await prior.detach();
      } on Object catch (_) {}
    }
    _log('rating-overlay: attach start');
    try {
      _overlay = await attachOverlay();
      _log('rating-overlay: attach ok');
    } on Object catch (e, st) {
      _log('rating-overlay: attach FAILED: $e\n$st');
      reportError(e, st, context: 'rating-overlay.attach');
      return;
    }
    if (_authListenerWired) {
      // Re-populate the new native view with current data. The events
      // client keeps running across view recreation, so we only need the
      // one-shot sync here.
      if (ref.read(authControllerProvider).valueOrNull != null) {
        unawaited(_fullSync());
      }
      return;
    }
    _authListenerWired = true;
    // Wire up auth *after* the first successful attach so we react to
    // login/logout without leaking a listener on a half-initialized overlay.
    ref.listen<AsyncValue<User?>>(authControllerProvider, (prev, next) {
      // `valueOrNull` instead of `.value`: the latter rethrows when the
      // state is `AsyncError` (e.g. anonymous-auth connection refused in
      // CI integration tests), which would crash the whole listener.
      final prevId = prev?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      _log('rating-overlay: auth change $prevId -> $nextId');
      if (prevId != nextId) {
        final overlay = _overlay;
        if (overlay != null) unawaited(overlay.clear());
        // Restart the SSE stream against the new session cookie so
        // invalidations are filtered for the right user. The client is
        // keyed to a Dio instance, not a user id, so stopping and starting
        // is cheap — it just drops the held socket.
        unawaited(_restartEventsClient());
        if (nextId != null) unawaited(_fullSync());
      }
    });
    // Kick off an initial fetch only if auth is already resolved. If it's
    // still loading the listener above handles the first transition, which
    // avoids a double-fetch on cold start. Use `valueOrNull` — plain
    // `.value` rethrows on `AsyncError`, which happens in CI integration
    // tests where anonymous-auth gets "connection refused".
    if (ref.read(authControllerProvider).valueOrNull != null) {
      unawaited(_fullSync());
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
    unawaited(_fullSync());
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

  /// Trigger an immediate full sync. Called by brush after a paint that
  /// involved server-side clipping, where we can't reconstruct the final
  /// state locally.
  Future<void> refreshAfterPaint() => _fullSync();

  /// Optimistically append a single rating polygon to the overlay without
  /// hitting the network. Safe only when the backend reported no clipping
  /// or deletions — otherwise the local and server views diverge until the
  /// next full sync.
  Future<void> appendLocal({
    required Map<String, dynamic> geometry,
    required int value,
    int? id,
  }) async {
    final overlay = _overlay;
    if (overlay == null) return;
    final prev = _lastCollection;
    final features = <dynamic>[
      if (prev != null) ...((prev['features'] as List?) ?? const []),
      {
        'type': 'Feature',
        if (id != null) 'id': id,
        'properties': {'value': value, if (id != null) 'id': id},
        'geometry': geometry,
      },
    ];
    final next = {'type': 'FeatureCollection', 'features': features};
    await overlay.update(next);
    _lastCollection = next;
  }

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
      _lastCollection = data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      _log('rating-overlay: sync failed status=${e.response?.statusCode} '
          'type=${e.type} msg=${e.message}');
    } on Object catch (e, st) {
      _log('rating-overlay: sync failed: $e');
      reportError(e, st, context: 'rating-overlay.sync');
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
