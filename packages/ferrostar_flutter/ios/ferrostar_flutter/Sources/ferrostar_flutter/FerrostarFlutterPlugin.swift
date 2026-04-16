#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterFramework)
import FlutterFramework
#endif
import Foundation
import UIKit

#if canImport(FerrostarCore) && canImport(FerrostarCoreFFI)
import FerrostarCore
import FerrostarCoreFFI
#endif

public final class FerrostarFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "land._001/ferrostar_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = FerrostarFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "smokeTest":
      #if canImport(FerrostarCore) && canImport(FerrostarCoreFFI)
      let sampleLocation = UserLocation(
        coordinates: GeographicCoordinate(lat: 52.52, lng: 13.405),
        horizontalAccuracy: 5.0,
        courseOverGround: nil,
        timestamp: Date(timeIntervalSince1970: 1_744_800_000),
        speed: nil
      )
      result("location created at \(sampleLocation.coordinates.lat), \(sampleLocation.coordinates.lng)")
      #else
      result(
        FlutterError(
          code: "internal",
          message: "FerrostarCore is only available when the plugin is built through Swift Package Manager.",
          details: nil
        )
      )
      #endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
