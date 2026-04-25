import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

const _cfg = AppConfig(
  apiBaseUrl: 'http://localhost',
  tileServerBaseUrl: 'http://localhost',
  tileStyleUrl: 'http://localhost/tiles',
  ratingsSseEnabled: false,
);

ProviderContainer _container({
  required SharedPreferences prefs,
  required FlutterTts tts,
}) {
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(_cfg),
    cookieStoragePathProvider.overrideWithValue('/tmp'),
    sharedPreferencesProvider.overrideWithValue(prefs),
    ttsFactoryProvider.overrideWithValue(() => tts),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('speakInstruction calls FlutterTts.speak with the given text', () async {
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    final prefs = await SharedPreferences.getInstance();
    final container = _container(prefs: prefs, tts: tts);

    final service = container.read(navigationServiceProvider);
    await service.speakInstruction('Turn left');

    verify(() => tts.speak('Turn left')).called(1);
  });

  test('flutterTtsProvider sets de-DE when LocalePref is de', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    _container(prefs: prefs, tts: tts).read(flutterTtsProvider);

    verify(() => tts.setLanguage('de-DE')).called(1);
  });

  test('flutterTtsProvider sets en-US when LocalePref is en', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    _container(prefs: prefs, tts: tts).read(flutterTtsProvider);

    verify(() => tts.setLanguage('en-US')).called(1);
  });
}
