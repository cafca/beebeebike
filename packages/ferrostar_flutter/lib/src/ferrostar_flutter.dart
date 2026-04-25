import 'package:ferrostar_flutter/src/controller.dart';
import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';

/// Entry point for the Ferrostar Flutter plugin.
///
/// Use [FerrostarFlutter.instance] to access the singleton facade and
/// [createController] to start a navigation session. Each session is owned by
/// a [FerrostarController] and must be disposed when no longer needed.
class FerrostarFlutter {
  FerrostarFlutter._();

  /// Singleton facade; routes calls to the active platform implementation.
  static final FerrostarFlutter instance = FerrostarFlutter._();

  /// Allocates a navigation controller on the native side from a precomputed
  /// OSRM route ([osrmJson]) and the [waypoints] used to request it.
  ///
  /// The returned [FerrostarController] owns native resources — call
  /// [FerrostarController.dispose] when finished. [config] is optional and
  /// defaults to the standard deviation thresholds.
  Future<FerrostarController> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    NavigationConfig config = const NavigationConfig(),
  }) async {
    final platform = FerrostarFlutterPlatform.instance;
    final id = await platform.createController(
      osrmJson: osrmJson,
      waypoints: waypoints,
      config: config,
    );
    return FerrostarController(id, platform);
  }
}
