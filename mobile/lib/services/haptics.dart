import 'package:haptic_feedback/haptic_feedback.dart' as hf;

class AppHaptics {
  static Future<void> firstFix() => _safe(hf.HapticsType.selection);
  static Future<void> routeCalcStart() => _safe(hf.HapticsType.light);
  static Future<void> routeSuccess() => _safe(hf.HapticsType.success);
  static Future<void> routeError() => _safe(hf.HapticsType.error);
  static Future<void> startRide() => _safe(hf.HapticsType.medium);
  static Future<void> offRoute() => _safe(hf.HapticsType.warning);
  static Future<void> arrived() => _safe(hf.HapticsType.success);

  static Future<void> _safe(hf.HapticsType type) async {
    try {
      if (await hf.Haptics.canVibrate()) {
        await hf.Haptics.vibrate(type);
      }
    } catch (_) {
      // Haptics are fire-and-forget; failure must never break app flow.
    }
  }
}
