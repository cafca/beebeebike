import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../navigation/location_converter.dart';
import '../navigation/navigation_service.dart';

final flutterTtsProvider = Provider<FlutterTts>((ref) => FlutterTts());

final navigationServiceProvider = Provider<NavigationService>((ref) {
  final dio = ref.watch(dioProvider);
  final routingApi = RoutingApi(dio);
  final tts = ref.watch(flutterTtsProvider);
  return NavigationService(
    createController: (osrmJson, waypoints) =>
        FerrostarFlutter.instance.createController(
          osrmJson: osrmJson,
          waypoints: waypoints,
        ),
    loadNavigationRoute: ({required origin, required destination}) =>
        routingApi.computeNavigationRoute(origin, destination),
    locationStream: Geolocator.getPositionStream().map(positionToUserLocation),
    speakInstruction: (text) async { await tts.speak(text); },
  );
});

final navigationStateProvider = StreamProvider<NavigationState>((ref) {
  return ref.watch(navigationServiceProvider).stateStream;
});
