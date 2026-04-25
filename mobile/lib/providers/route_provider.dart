import 'dart:async';

import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/api/routing_api.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/models/route_preview.dart';
import 'package:beebeebike/models/route_state.dart';
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';
import 'package:beebeebike/providers/supported_bbox_provider.dart';
import 'package:beebeebike/services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel error string set on [RouteState.error] when the route origin
/// (typically the user's GPS fix) lies outside the supported coverage bbox.
/// Consumers (e.g. RouteSheet) map this to a localized message instead of
/// the generic "could not load route" text.
const kRouteErrorOriginOutsideBbox = '__beebeebike_origin_outside_bbox__';

typedef RoutePreviewLoader = Future<RoutePreview> Function({
  required Location origin,
  required Location destination,
});

final routePreviewLoaderProvider = Provider<RoutePreviewLoader>((ref) {
  final api = RoutingApi(ref.watch(dioProvider));
  return ({required origin, required destination}) {
    return api.computeRoute(
      [origin.lng, origin.lat],
      [destination.lng, destination.lat],
      ratingWeight: 0.5,
      distanceInfluence: 70,
    );
  };
});

final routeControllerProvider =
    NotifierProvider<RouteController, RouteState>(RouteController.new);

class RouteController extends Notifier<RouteState> {
  @override
  RouteState build() {
    ref.listen<AsyncValue<User?>>(authControllerProvider, (prev, next) {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;
      if (prevUser?.accountType == 'anonymous' &&
          nextUser != null &&
          nextUser.accountType != 'anonymous') {
        unawaited(_maybeLoadPreview());
      }
    });
    return const RouteState();
  }

  Future<void> setOrigin(Location origin) async {
    state = state.copyWith(origin: origin, error: null);
    await _maybeLoadPreview();
  }

  Future<void> setDestination(Location destination) async {
    state = state.copyWith(destination: destination, error: null);
    await _maybeLoadPreview();
  }

  int _loadGeneration = 0;

  Future<void> _maybeLoadPreview() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;
    if (origin.lat == destination.lat && origin.lng == destination.lng) {
      state = state.copyWith(
        isLoading: false,
        error: 'Origin and destination are the same',
        preview: null,
      );
      unawaited(AppHaptics.routeError());
      return;
    }
    final bbox = ref.read(supportedBboxProvider);
    if (bbox != null && !bbox.contains(origin.lat, origin.lng)) {
      state = state.copyWith(
        isLoading: false,
        error: kRouteErrorOriginOutsideBbox,
        preview: null,
      );
      unawaited(AppHaptics.routeError());
      return;
    }

    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null, preview: null);
    unawaited(AppHaptics.routeCalcStart());
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(preview: preview, isLoading: false);
      unawaited(AppHaptics.routeSuccess());
    } on Object catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error.toString());
      unawaited(AppHaptics.routeError());
    }
  }

  void clear() {
    state = const RouteState();
  }

  /// Re-fetches the preview for the current origin/destination without
  /// clearing the existing one. Used when something off-screen (e.g. a
  /// rating change from the brush) should refresh the drawn route in
  /// place. No fit-to-bounds, no success haptic — the old route stays
  /// visible (dimmed by the map layer) until the new one arrives.
  Future<void> recomputePreview() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;
    if (origin.lat == destination.lat && origin.lng == destination.lng) return;
    final bbox = ref.read(supportedBboxProvider);
    if (bbox != null && !bbox.contains(origin.lat, origin.lng)) {
      state = state.copyWith(
        isLoading: false,
        error: kRouteErrorOriginOutsideBbox,
      );
      return;
    }
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(preview: preview, isLoading: false);
    } on Object catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
