import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How aggressively the router should avoid cobblestone surfaces. Mirrors the
/// backend's `CobblestoneAvoidance` enum and serializes to the same snake_case
/// strings (`allow`, `default`, `strong`).
enum CobblestoneAvoidance {
  allow,
  defaultLevel,
  strong,
}

extension CobblestoneAvoidanceX on CobblestoneAvoidance {
  /// Wire format sent to `POST /api/route` and `POST /api/navigate`.
  String get wireValue => switch (this) {
        CobblestoneAvoidance.allow => 'allow',
        CobblestoneAvoidance.defaultLevel => 'default',
        CobblestoneAvoidance.strong => 'strong',
      };
}

const _storageKey = 'cobblestone_avoidance';

final cobblestoneAvoidanceProvider =
    NotifierProvider<CobblestoneAvoidanceController, CobblestoneAvoidance>(
        CobblestoneAvoidanceController.new);

class CobblestoneAvoidanceController extends Notifier<CobblestoneAvoidance> {
  @override
  CobblestoneAvoidance build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _decode(prefs.getString(_storageKey));
  }

  Future<void> setPref(CobblestoneAvoidance next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, next.wireValue);
  }

  static CobblestoneAvoidance _decode(String? raw) {
    switch (raw) {
      case 'allow':
        return CobblestoneAvoidance.allow;
      case 'strong':
        return CobblestoneAvoidance.strong;
      case 'default':
      default:
        return CobblestoneAvoidance.defaultLevel;
    }
  }
}
