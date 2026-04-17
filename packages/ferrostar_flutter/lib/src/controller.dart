import 'ferrostar_flutter_platform.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';

class FerrostarController {
  FerrostarController(this._id, this._platform);

  final String _id;
  final FerrostarFlutterPlatform _platform;
  bool _disposed = false;

  String get id => _id;

  Stream<NavigationState> get stateStream =>
      _platform.stateStream(controllerId: _id);

  Stream<SpokenInstruction> get spokenInstructionStream =>
      _platform.spokenInstructionStream(controllerId: _id);

  Stream<RouteDeviation> get deviationStream =>
      _platform.deviationStream(controllerId: _id);

  Future<void> updateLocation(UserLocation location) {
    _requireAlive();
    return _platform.updateLocation(controllerId: _id, location: location);
  }

  Future<void> replaceRoute(Map<String, dynamic> osrmJson) {
    _requireAlive();
    return _platform.replaceRoute(controllerId: _id, osrmJson: osrmJson);
  }

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
