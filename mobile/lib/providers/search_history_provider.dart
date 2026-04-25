import 'dart:convert';

import 'package:beebeebike/models/location.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _recentSearchesKey = 'beebeebike.recentSearches';

final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('override in main/test');
});

final searchHistoryProvider =
    NotifierProvider<SearchHistoryController, List<Location>>(SearchHistoryController.new);

class SearchHistoryController extends Notifier<List<Location>> {
  @override
  List<Location> build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getStringList(_recentSearchesKey) ?? const [];
    return raw
        .map((entry) => Location.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();
  }

  Future<void> remember(Location location) async {
    final next = [
      location,
      ...state.where((entry) => entry.id != location.id),
    ].take(10).toList();
    state = next;

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setStringList(
      _recentSearchesKey,
      next.map((entry) => jsonEncode(entry.toJson())).toList(),
    );
  }
}
