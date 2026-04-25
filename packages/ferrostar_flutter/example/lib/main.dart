import 'dart:convert';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: E2EHome()));

class E2EHome extends StatefulWidget {
  const E2EHome({super.key});
  @override
  State<E2EHome> createState() => _E2EHomeState();
}

class _E2EHomeState extends State<E2EHome> {
  FerrostarController? _ctrl;
  NavigationState? _state;
  String _log = '';
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final jsonStr = await rootBundle.loadString('assets/sample_osrm_route.json');
      final osrm = json.decode(jsonStr) as Map<String, dynamic>;

      final ctrl = await FerrostarFlutter.instance.createController(
        osrmJson: osrm,
        waypoints: [
          const WaypointInput(lat: 59.442643, lng: 24.765368),
          const WaypointInput(lat: 59.452226, lng: 24.730034),
        ],
      );
      ctrl.stateStream.listen((s) => setState(() => _state = s));
      ctrl.spokenInstructionStream.listen(
          (s) => setState(() => _log = 'SPOKEN: ${s.text}'));
      ctrl.deviationStream.listen(
          (d) => setState(() => _log = 'DEVIATION: ${d.deviationM}m'));
      setState(() {
        _ctrl = ctrl;
        _log = 'Controller ready';
      });
    } on Object catch (e) {
      setState(() => _log = 'Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _tick() async {
    try {
      await _ctrl?.updateLocation(UserLocation(
        lat: 59.4429,
        lng: 24.7653,
        horizontalAccuracyM: 5,
        courseDeg: 315,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ));
    } on Object catch (e) {
      setState(() => _log = 'Tick error: $e');
    }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        appBar: AppBar(title: const Text('ferrostar_flutter E2E')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                ElevatedButton(
                  onPressed: _loading ? null : _start,
                  child: Text(_loading ? 'Loading...' : 'Start'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _ctrl == null ? null : _tick,
                  child: const Text('Send location'),
                ),
              ]),
              const SizedBox(height: 16),
              Text('Status: ${_state?.status.name ?? "(none)"}'),
              if (_state?.currentVisual != null)
                Text('Instruction: ${_state!.currentVisual!.primaryText}'),
              if (_state?.progress != null)
                Text(
                  'Remaining: ${_state!.progress!.distanceRemainingM.toStringAsFixed(0)}m',
                ),
              const SizedBox(height: 16),
              Text('Log: $_log'),
            ],
          ),
        ),
      );
}
