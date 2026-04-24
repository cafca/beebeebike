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
import '../services/error_reporter.dart';
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

/// Whether turn-by-turn voice is currently enabled. Toggled by the voice FAB
/// during navigation; gates every TTS `speak` call the nav layer makes.
final ttsEnabledProvider = StateProvider<bool>((_) => true);

final flutterTtsProvider = Provider<FlutterTts>((ref) {
  final tts = ref.watch(ttsFactoryProvider)();
  final pref = ref.watch(localeProvider);
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  final tag = effectiveLanguageTag(pref, deviceLocale);
  final ttsTag = tag == 'de' ? 'de-DE' : 'en-US';
  tts.setLanguage(ttsTag);
  // Fire-and-forget: upgrade to the best locally installed voice. iOS ships
  // a "default" voice per language; users who downloaded Enhanced/Premium
  // voices get a much better sounding cue without any extra UI.
  _applyBestVoice(tts, ttsTag);
  return tts;
});

Future<void> _applyBestVoice(FlutterTts tts, String localeTag) async {
  try {
    final raw = await tts.getVoices;
    if (raw is! List) return;
    final matches = <Map<String, String>>[];
    for (final v in raw) {
      if (v is! Map) continue;
      final locale = v['locale']?.toString() ?? '';
      if (!locale.toLowerCase().startsWith(localeTag.toLowerCase())) continue;
      matches.add({
        'name': v['name']?.toString() ?? '',
        'locale': locale,
        'identifier': v['identifier']?.toString() ?? '',
        'quality': v['quality']?.toString() ?? '',
      });
    }
    if (matches.isEmpty) return;
    int rank(String q) => switch (q.toLowerCase()) {
          'premium' => 3,
          'enhanced' => 2,
          'default' => 1,
          _ => 0,
        };
    matches.sort((a, b) => rank(b['quality']!).compareTo(rank(a['quality']!)));
    final best = matches.first;
    debugPrint(
        'nav: tts voice="${best['name']}" quality=${best['quality']} locale=${best['locale']}');
    await tts.setVoice({
      'name': best['name']!,
      'locale': best['locale']!,
      if (best['identifier']!.isNotEmpty) 'identifier': best['identifier']!,
    });
  } catch (e) {
    debugPrint('nav: tts voice pick failed: $e');
  }
}

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
      if (!ref.read(ttsEnabledProvider)) return;
      try {
        await tts.speak(text);
      } catch (e) {
        // TTS speak fails routinely on audio-session interruptions, silent
        // mode switches, and mid-utterance cancellations. Drop a breadcrumb
        // for context around nearby issues but don't surface as its own
        // GlitchTip event — the noise swamps anything actionable.
        addBreadcrumb('nav.tts speak failed: $e', category: 'tts');
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

final rerouteSucceededProvider = StreamProvider.autoDispose<void>((ref) {
  return ref.watch(navigationServiceProvider).rerouteSucceededStream;
});
