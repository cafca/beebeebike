import 'package:ferrostar_flutter/src/method_channel_platform.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFerrostarFlutter();
  const channel = MethodChannel('land._001/ferrostar_flutter');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'createController':
          return 'ctrl-1';
        case 'updateLocation':
          return null;
        case 'replaceRoute':
          return null;
        case 'dispose':
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createController sends osrm_json, waypoints, config', () async {
    final id = await platform.createController(
      osrmJson: {'code': 'Ok', 'routes': <Object?>[]},
      waypoints: [
        const WaypointInput(lat: 52.52, lng: 13.405),
        const WaypointInput(lat: 52.50, lng: 13.40),
      ],
      config: const NavigationConfig(),
    );
    expect(id, 'ctrl-1');
    expect(log, hasLength(1));
    expect(log.first.method, 'createController');
    final args = log.first.arguments as Map<dynamic, dynamic>;
    expect(args['osrm_json'], isA<Map<dynamic, dynamic>>());
    expect(args['waypoints'] as List<dynamic>, hasLength(2));
    expect(args['config'], isA<Map<dynamic, dynamic>>());
  });

  test('updateLocation sends controller_id and location map', () async {
    await platform.updateLocation(
      controllerId: 'ctrl-1',
      location: const UserLocation(
        lat: 52.52,
        lng: 13.405,
        horizontalAccuracyM: 5,
        timestampMs: 1,
      ),
    );
    expect(log.single.method, 'updateLocation');
    final args = log.single.arguments as Map;
    expect(args['controller_id'], 'ctrl-1');
    expect((args['location'] as Map)['lat'], 52.52);
  });

  test('replaceRoute sends controller_id and osrm_json', () async {
    await platform.replaceRoute(
      controllerId: 'ctrl-1',
      osrmJson: {'code': 'Ok', 'routes': <Object?>[]},
    );
    expect(log.single.method, 'replaceRoute');
  });

  test('dispose sends controller_id', () async {
    await platform.dispose(controllerId: 'ctrl-1');
    expect(log.single.method, 'dispose');
    expect((log.single.arguments as Map)['controller_id'], 'ctrl-1');
  });
}
