import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to LocalePref.system with no stored value', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    final pref = c.read(localeProvider);
    expect(pref, LocalePref.system);
    expect(pref.materialLocale, isNull);
  });

  test('reads stored de on construction', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    final pref = c.read(localeProvider);
    expect(pref, LocalePref.de);
    expect(pref.materialLocale, const Locale('de'));
  });

  test('setPref persists and updates state', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    await c.read(localeProvider.notifier).setPref(LocalePref.en);
    final pref = c.read(localeProvider);
    expect(pref, LocalePref.en);
    expect(prefs.getString('locale_pref'), 'en');
    expect(pref.materialLocale, const Locale('en'));
  });

  test('setPref(system) stores "system", materialLocale is null', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    await c.read(localeProvider.notifier).setPref(LocalePref.system);
    final pref = c.read(localeProvider);
    expect(pref, LocalePref.system);
    expect(prefs.getString('locale_pref'), 'system');
    expect(pref.materialLocale, isNull);
  });

  test('unknown stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'fr'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    expect(c.read(localeProvider), LocalePref.system);
  });

  test('effectiveLanguageTag maps pref/device to en|de', () {
    expect(effectiveLanguageTag(LocalePref.en, const Locale('de')), 'en');
    expect(effectiveLanguageTag(LocalePref.de, const Locale('en')), 'de');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('de')), 'de');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('en')), 'en');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('fr')), 'en');
  });
}
