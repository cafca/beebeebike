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
typedef LocationStreamFactory = Stream<UserLocation> Function();

class NavigationService {
  NavigationService({
    required this.createController,
    required this.loadNavigationRoute,
    required this.locationStreamFactory,
    required this.speakInstruction,
  });

  final CreateController createController;
  final LoadNavigationRoute loadNavigationRoute;
  final LocationStreamFactory locationStreamFactory;
  final SpeakInstruction speakInstruction;

  FerrostarController? _controller;
  StreamSubscription<UserLocation>? _locationSub;
  StreamSubscription<SpokenInstruction>? _spokenSub;
  StreamSubscription<RouteDeviation>? _deviationSub;
  StreamSubscription<NavigationState>? _stateSub;
  WaypointInput? _destination;
  bool _rerouteInProgress = false;

  final _stateController = StreamController<NavigationState>.broadcast();
  final _rerouteController = StreamController<bool>.broadcast();

  Stream<NavigationState> get stateStream => _stateController.stream;

  /// Emits `true` when a reroute starts and `false` when it finishes
  /// (success or failure). Consumers should hide UI "rerouting" affordances
  /// the moment this flips back to `false`, without waiting on a fresh
  /// [NavigationState] (which only arrives on the next GPS update).
  Stream<bool> get rerouteInProgressStream => _rerouteController.stream;

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
      (instruction) {
        speakInstruction(instruction.text);
      },
    );

    _deviationSub = _controller!.deviationStream.listen((deviation) async {
      if (_rerouteInProgress) return;
      _rerouteInProgress = true;
      _rerouteController.add(true);
      debugPrint(
          'nav: deviation ${deviation.deviationM.toStringAsFixed(0)}m, rerouting');
      try {
        final dest = _destination;
        final controller = _controller;
        if (dest == null || controller == null) return;
        final rerouteJson = await loadNavigationRoute(
          origin: [deviation.userLocation.lng, deviation.userLocation.lat],
          destination: [dest.lng, dest.lat],
        );
        if (_controller == null) return;
        await controller.replaceRoute(rerouteJson);
      } catch (e, st) {
        debugPrint('nav: reroute error: $e\n$st');
      } finally {
        _rerouteInProgress = false;
        _rerouteController.add(false);
      }
    });

    _locationSub = locationStreamFactory().listen(
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
    _rerouteInProgress = false;
  }
}
