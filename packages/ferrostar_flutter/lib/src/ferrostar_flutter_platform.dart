import 'package:ferrostar_flutter/src/method_channel_platform.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';
import 'package:ferrostar_flutter/src/models/navigation_state.dart';
import 'package:ferrostar_flutter/src/models/route_deviation.dart';
import 'package:ferrostar_flutter/src/models/spoken_instruction.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Platform interface for the Ferrostar plugin.
///
/// Concrete implementations (the bundled [MethodChannelFerrostarFlutter] for
/// real platforms, fakes in tests) extend this class. Replace
/// [FerrostarFlutterPlatform.instance] in tests to mock the entire native
/// boundary.
abstract class FerrostarFlutterPlatform extends PlatformInterface {
  /// Subclass constructor; passes a token used to verify subclasses.
  FerrostarFlutterPlatform() : super(token: _token);
  static final Object _token = Object();

  static FerrostarFlutterPlatform _instance = MethodChannelFerrostarFlutter();

  /// The active platform implementation. Defaults to the method-channel
  /// backend; tests replace it with a fake.
  static FerrostarFlutterPlatform get instance => _instance;
  static set instance(FerrostarFlutterPlatform inst) {
    PlatformInterface.verifyToken(inst, _token);
    _instance = inst;
  }

  /// Creates a native controller for the given OSRM route and waypoints, and
  /// returns its opaque id.
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  });

  /// Pushes a new GPS fix into the controller identified by [controllerId].
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  });

  /// Replaces the active route on the controller identified by [controllerId].
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  });

  /// Releases the native controller identified by [controllerId].
  Future<void> dispose({required String controllerId});

  /// Returns the navigation-state stream for [controllerId].
  Stream<NavigationState> stateStream({required String controllerId});

  /// Returns the spoken-instruction stream for [controllerId].
  Stream<SpokenInstruction> spokenInstructionStream({
    required String controllerId,
  });

  /// Returns the route-deviation stream for [controllerId].
  Stream<RouteDeviation> deviationStream({required String controllerId});
}
