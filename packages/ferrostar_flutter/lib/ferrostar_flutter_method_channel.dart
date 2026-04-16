import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ferrostar_flutter_platform_interface.dart';

/// An implementation of [FerrostarFlutterPlatform] that uses method channels.
class MethodChannelFerrostarFlutter extends FerrostarFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ferrostar_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
