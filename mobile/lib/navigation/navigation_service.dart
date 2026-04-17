import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/foundation.dart';

typedef CreateController = Future<FerrostarController> Function(
  Map<String, dynamic> osrmJson,
  List<WaypointInput> waypoints,
);
typedef LoadNavigationRoute = Future<Map<String, dynamic>> Function({
  required List<double> origin,
  required List<double> destination,
});
typedef SpeakInstruction = Future<void> Function(String text);

class NavigationService {
  NavigationService({
    required this.createController,
    required this.loadNavigationRoute,
    required this.locationStream,
    required this.speakInstruction,
  });

  final CreateController createController;
  final LoadNavigationRoute loadNavigationRoute;
  final Stream<UserLocation> locationStream;
  final SpeakInstruction speakInstruction;

  FerrostarController? _controller;
  StreamSubscription<UserLocation>? _locationSub;
  StreamSubscription<SpokenInstruction>? _spokenSub;
  StreamSubscription<RouteDeviation>? _deviationSub;
  StreamSubscription<NavigationState>? _stateSub;
  WaypointInput? _destination;

  final _stateController = StreamController<NavigationState>.broadcast();

  Stream<NavigationState> get stateStream => _stateController.stream;

  Future<void> start({
    required WaypointInput origin,
    required WaypointInput destination,
  }) async {
    await dispose();
    _destination = destination;
    final routeJson = await loadNavigationRoute(
      origin: [origin.lng, origin.lat],
      destination: [destination.lng, destination.lat],
    );
    final waypoints = [origin, destination];
    _controller = await createController(routeJson, waypoints);

    _stateSub = _controller!.stateStream.listen(
      _stateController.add,
      onError: _stateController.addError,
    );

    _spokenSub = _controller!.spokenInstructionStream.listen(
      (instruction) => speakInstruction(instruction.text),
    );

    _deviationSub = _controller!.deviationStream.listen((deviation) async {
      try {
        final dest = _destination;
        if (dest == null) return;
        final rerouteJson = await loadNavigationRoute(
          origin: [deviation.userLocation.lng, deviation.userLocation.lat],
          destination: [dest.lng, dest.lat],
        );
        await _controller!.replaceRoute(rerouteJson);
      } catch (e, st) {
        debugPrint('NavigationService reroute error: $e\n$st');
      }
    });

    _locationSub = locationStream.listen(
      (location) => _controller?.updateLocation(location),
    );
  }

  Future<void> dispose() async {
    await _locationSub?.cancel();
    await _spokenSub?.cancel();
    await _deviationSub?.cancel();
    await _stateSub?.cancel();
    await _controller?.dispose();
    _locationSub = null;
    _spokenSub = null;
    _deviationSub = null;
    _stateSub = null;
    _controller = null;
  }
}
