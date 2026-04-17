import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'models/navigation_config.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';
import 'models/waypoint_input.dart';
import 'method_channel_platform.dart';

abstract class FerrostarFlutterPlatform extends PlatformInterface {
  FerrostarFlutterPlatform() : super(token: _token);
  static final Object _token = Object();

  static FerrostarFlutterPlatform _instance = MethodChannelFerrostarFlutter();
  static FerrostarFlutterPlatform get instance => _instance;
  static set instance(FerrostarFlutterPlatform inst) {
    PlatformInterface.verifyToken(inst, _token);
    _instance = inst;
  }

  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  });

  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  });

  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  });

  Future<void> dispose({required String controllerId});

  Stream<NavigationState> stateStream({required String controllerId});
  Stream<SpokenInstruction> spokenInstructionStream({required String controllerId});
  Stream<RouteDeviation> deviationStream({required String controllerId});
}
