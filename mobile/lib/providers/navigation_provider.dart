import 'dart:ui' as ui;

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../navigation/location_converter.dart';
import '../navigation/navigation_service.dart';
import 'locale_provider.dart';

Stream<UserLocation> _buildLocationStream() async* {
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever ||
      permission == LocationPermission.denied) {
    debugPrint('nav: location permission denied');
    return;
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    ),
  ).map(positionToUserLocation);
}

final ttsFactoryProvider = Provider<FlutterTts Function()>((_) => FlutterTts.new);

final flutterTtsProvider = Provider<FlutterTts>((ref) {
  final tts = ref.watch(ttsFactoryProvider)();
  final pref = ref.watch(localeProvider);
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  final tag = effectiveLanguageTag(pref, deviceLocale);
  final ttsTag = tag == 'de' ? 'de-DE' : 'en-US';
  tts.setLanguage(ttsTag);
  return tts;
});

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
    locationStreamFactory: _buildLocationStream,
    speakInstruction: (text) async {
      try {
        await tts.speak(text);
      } catch (e) {
        debugPrint('nav: tts error: $e');
      }
    },
  );
});

final navigationStateProvider = StreamProvider.autoDispose<NavigationState>((ref) {
  return ref.watch(navigationServiceProvider).stateStream;
});

final rerouteInProgressProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(navigationServiceProvider).rerouteInProgressStream;
});
