package land._001.ferrostar_flutter

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// TODO(android): implement method channel handler using Ferrostar NavigationController
object ControllerBridge {
    fun handle(call: MethodCall, result: MethodChannel.Result, messenger: BinaryMessenger) {
        result.notImplemented()
    }
}
