import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ferrostar_flutter_method_channel.dart';

abstract class FerrostarFlutterPlatform extends PlatformInterface {
  /// Constructs a FerrostarFlutterPlatform.
  FerrostarFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static FerrostarFlutterPlatform _instance = MethodChannelFerrostarFlutter();

  /// The default instance of [FerrostarFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelFerrostarFlutter].
  static FerrostarFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FerrostarFlutterPlatform] when
  /// they register themselves.
  static set instance(FerrostarFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
