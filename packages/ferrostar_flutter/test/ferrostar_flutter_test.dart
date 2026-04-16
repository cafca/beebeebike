import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ferrostar_flutter/ferrostar_flutter_platform_interface.dart';
import 'package:ferrostar_flutter/ferrostar_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFerrostarFlutterPlatform
    with MockPlatformInterfaceMixin
    implements FerrostarFlutterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FerrostarFlutterPlatform initialPlatform = FerrostarFlutterPlatform.instance;

  test('$MethodChannelFerrostarFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFerrostarFlutter>());
  });

  test('getPlatformVersion', () async {
    FerrostarFlutter ferrostarFlutterPlugin = FerrostarFlutter();
    MockFerrostarFlutterPlatform fakePlatform = MockFerrostarFlutterPlatform();
    FerrostarFlutterPlatform.instance = fakePlatform;

    expect(await ferrostarFlutterPlugin.getPlatformVersion(), '42');
  });
}
