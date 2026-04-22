import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_history_provider.dart';

/// User language preference. `system` defers to the device locale; `en` and
/// `de` pin the app.
enum LocalePref { system, en, de }

const _storageKey = 'locale_pref';

final localeProvider =
    NotifierProvider<LocaleController, LocalePref>(LocaleController.new);

class LocaleController extends Notifier<LocalePref> {
  @override
  LocalePref build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _decode(prefs.getString(_storageKey));
  }

  Locale? get materialLocale {
    switch (state) {
      case LocalePref.system:
        return null;
      case LocalePref.en:
        return const Locale('en');
      case LocalePref.de:
        return const Locale('de');
    }
  }

  Future<void> setPref(LocalePref next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, _encode(next));
  }

  static LocalePref _decode(String? raw) {
    switch (raw) {
      case 'en':
        return LocalePref.en;
      case 'de':
        return LocalePref.de;
      case 'system':
      default:
        return LocalePref.system;
    }
  }

  static String _encode(LocalePref v) {
    switch (v) {
      case LocalePref.system:
        return 'system';
      case LocalePref.en:
        return 'en';
      case LocalePref.de:
        return 'de';
    }
  }
}

/// Resolve the effective BCP-47 language tag (two letters) for the app.
/// Device locales outside the supported set fall back to `en`.
String effectiveLanguageTag(LocalePref pref, Locale deviceLocale) {
  switch (pref) {
    case LocalePref.en:
      return 'en';
    case LocalePref.de:
      return 'de';
    case LocalePref.system:
      return deviceLocale.languageCode == 'de' ? 'de' : 'en';
  }
}
