import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../models/location.dart';
import '../models/route_preview.dart';
import '../models/route_state.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/haptics.dart';

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
        _maybeLoadPreview();
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
      AppHaptics.routeError();
      return;
    }

    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null, preview: null);
    AppHaptics.routeCalcStart();
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(preview: preview, isLoading: false);
      AppHaptics.routeSuccess();
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error.toString());
      AppHaptics.routeError();
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
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
