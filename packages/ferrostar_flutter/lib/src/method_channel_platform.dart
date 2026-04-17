import 'dart:async';
import 'package:flutter/services.dart';
import 'ferrostar_flutter_platform.dart';
import 'models/navigation_config.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';
import 'models/waypoint_input.dart';

const _channelName = 'land._001/ferrostar_flutter';

/// Recursively converts Map<Object?, Object?> → Map<String, dynamic> and
/// List elements, so platform-channel payloads are safe for fromJson.
dynamic _deepNormalize(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (e) => MapEntry(e.key.toString(), _deepNormalize(e.value)),
      ),
    );
  }
  if (value is List) {
    return value.map(_deepNormalize).toList();
  }
  return value;
}

class MethodChannelFerrostarFlutter extends FerrostarFlutterPlatform {
  final MethodChannel _channel = const MethodChannel(_channelName);

  @override
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  }) async {
    final result = await _channel.invokeMethod<String>('createController', {
      'osrm_json': osrmJson,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'config': config.toJson(),
    });
    return result!;
  }

  @override
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  }) async {
    await _channel.invokeMethod<void>('updateLocation', {
      'controller_id': controllerId,
      'location': location.toJson(),
    });
  }

  @override
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  }) async {
    await _channel.invokeMethod<void>('replaceRoute', {
      'controller_id': controllerId,
      'osrm_json': osrmJson,
    });
  }

  @override
  Future<void> dispose({required String controllerId}) async {
    await _channel.invokeMethod<void>('dispose', {'controller_id': controllerId});
  }

  @override
  Stream<NavigationState> stateStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/state/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => NavigationState.fromJson(_deepNormalize(e) as Map<String, dynamic>));
  }

  @override
  Stream<SpokenInstruction> spokenInstructionStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/spoken/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => SpokenInstruction.fromJson(_deepNormalize(e) as Map<String, dynamic>));
  }

  @override
  Stream<RouteDeviation> deviationStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/deviation/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => RouteDeviation.fromJson(_deepNormalize(e) as Map<String, dynamic>));
  }
}
