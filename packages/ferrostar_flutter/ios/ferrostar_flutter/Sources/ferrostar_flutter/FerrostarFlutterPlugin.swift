#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterFramework)
import FlutterFramework
#endif
import Foundation
import UIKit

public final class FerrostarFlutterPlugin: NSObject, FlutterPlugin {
  private static var sharedMessenger: FlutterBinaryMessenger?

  public static func register(with registrar: FlutterPluginRegistrar) {
    sharedMessenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: "land._001/ferrostar_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = FerrostarFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let messenger = FerrostarFlutterPlugin.sharedMessenger else {
      result(FlutterError(code: "internal", message: "No binary messenger", details: nil))
      return
    }
    ControllerBridge.handle(call: call, result: result, messenger: messenger)
  }
}
