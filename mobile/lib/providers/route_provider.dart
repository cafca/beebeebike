import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../models/location.dart';
import '../models/route_preview.dart';
import '../models/route_state.dart';

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
  RouteState build() => const RouteState();

  Future<void> setOrigin(Location origin) async {
    state = state.copyWith(origin: origin, error: null);
    await _maybeLoadPreview();
  }

  Future<void> setDestination(Location destination) async {
    state = state.copyWith(destination: destination, error: null);
    await _maybeLoadPreview();
  }

  Future<void> _maybeLoadPreview() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void clear() {
    state = const RouteState();
  }
}
