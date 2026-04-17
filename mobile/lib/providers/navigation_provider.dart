import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../navigation/navigation_service.dart';

final navigationServiceProvider = Provider<NavigationService>((ref) {
  final dio = ref.watch(dioProvider);
  final routingApi = RoutingApi(dio);
  return NavigationService(
    createController: (osrmJson, waypoints) =>
        FerrostarFlutter.instance.createController(
          osrmJson: osrmJson,
          waypoints: waypoints,
        ),
    loadNavigationRoute: ({required origin, required destination}) =>
        routingApi.computeNavigationRoute(origin, destination),
    locationStream: const Stream.empty(),
    speakInstruction: (_) async {},
  );
});
