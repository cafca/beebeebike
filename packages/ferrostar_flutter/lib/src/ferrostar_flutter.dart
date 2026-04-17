import 'controller.dart';
import 'ferrostar_flutter_platform.dart';
import 'models/navigation_config.dart';
import 'models/waypoint_input.dart';

class FerrostarFlutter {
  FerrostarFlutter._();
  static final FerrostarFlutter instance = FerrostarFlutter._();

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
