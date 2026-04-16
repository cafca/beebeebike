
import 'ferrostar_flutter_platform_interface.dart';

class FerrostarFlutter {
  Future<String?> getPlatformVersion() {
    return FerrostarFlutterPlatform.instance.getPlatformVersion();
  }
}
