import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';
import 'package:ferrostar_flutter/src/models/navigation_state.dart';
import 'package:ferrostar_flutter/src/models/route_deviation.dart';
import 'package:ferrostar_flutter/src/models/spoken_instruction.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';

/// Handle to a single navigation session managed by the native Ferrostar core.
///
/// Obtained from `FerrostarFlutter.createController`. Each instance owns a
/// platform-side controller identified by [id]; you must call [dispose] when
/// done so the native resources (location subscriptions, event channels) are
/// released. Once disposed, further calls throw [StateError].
class FerrostarController {
  /// Wraps a platform-allocated controller with the given [id], routing
  /// subsequent calls through [_platform]. Normally constructed by
  /// `FerrostarFlutter.createController`.
  FerrostarController(this._id, this._platform);

  final String _id;
  final FerrostarFlutterPlatform _platform;
  bool _disposed = false;

  /// Opaque platform-side controller identifier. Stable for the lifetime of
  /// this instance; useful for logging and correlating native traces.
  String get id => _id;

  /// Stream of navigation state snapshots (status, snapped location, current
  /// step, progress, visual instruction). Emits whenever the core re-evaluates
  /// state — typically after each [updateLocation] call.
  Stream<NavigationState> get stateStream =>
      _platform.stateStream(controllerId: _id);

  /// Stream of spoken instructions that have crossed their trigger distance.
  /// Each event represents a single utterance to be passed to a TTS engine.
  Stream<SpokenInstruction> get spokenInstructionStream =>
      _platform.spokenInstructionStream(controllerId: _id);

  /// Stream of route-deviation events. Emits when the core determines the
  /// user has been off-route beyond the configured distance and time
  /// thresholds; consumers typically respond by requesting a new route.
  Stream<RouteDeviation> get deviationStream =>
      _platform.deviationStream(controllerId: _id);

  /// Pushes a new GPS fix into the navigation core. Drives all downstream
  /// state and event streams. Throws [StateError] if the controller has
  /// already been disposed.
  Future<void> updateLocation(UserLocation location) {
    _requireAlive();
    return _platform.updateLocation(controllerId: _id, location: location);
  }

  /// Replaces the active route with a freshly fetched OSRM response (e.g.
  /// after a deviation). The current location and progress are preserved
  /// where possible. Throws [StateError] if disposed.
  Future<void> replaceRoute(Map<String, dynamic> osrmJson) {
    _requireAlive();
    return _platform.replaceRoute(controllerId: _id, osrmJson: osrmJson);
  }

  /// Tears down the platform-side controller and closes its event channels.
  /// Idempotent — calling multiple times is safe but only the first call
  /// performs work.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _platform.dispose(controllerId: _id);
  }

  void _requireAlive() {
    if (_disposed) {
      throw StateError('FerrostarController($_id) already disposed');
    }
  }
}
