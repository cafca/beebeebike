#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterFramework)
import FlutterFramework
#endif
import FerrostarCore
import FerrostarCoreFFI

final class ControllerBridge {

  static func handle(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    messenger: FlutterBinaryMessenger
  ) {
    switch call.method {
    case "createController": createController(args: call.arguments, result: result, messenger: messenger)
    case "updateLocation": updateLocation(args: call.arguments, result: result)
    case "replaceRoute": replaceRoute(args: call.arguments, result: result)
    case "dispose": dispose(args: call.arguments, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private static func createController(
    args: Any?, result: @escaping FlutterResult, messenger: FlutterBinaryMessenger
  ) {
    guard let dict = args as? [String: Any],
          let osrm = dict["osrm_json"] as? [String: Any],
          let waypointsJson = dict["waypoints"] as? [[String: Any]],
          let configJson = dict["config"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "createController: bad args", details: nil))
      return
    }

    do {
      let waypoints: [Waypoint] = try waypointsJson.map { try Serialization.decodeWaypoint($0) }
      let routeData = try extractRouteData(from: osrm)
      let route = try createRouteFromOsrmRoute(
        routeData: routeData,
        waypoints: waypoints,
        polylinePrecision: 6
      )

      let config = try Serialization.decodeConfig(configJson)
      let controller = createNavigator(route: route, config: config, shouldRecord: false)

      let id = ControllerRegistry.shared.register(controller: controller, config: config)

      StreamEmitters.register(controllerId: id, kind: .state, messenger: messenger)
      StreamEmitters.register(controllerId: id, kind: .spoken, messenger: messenger)
      StreamEmitters.register(controllerId: id, kind: .deviation, messenger: messenger)

      result(id)
    } catch let err as Serialization.SerializationError {
      result(FlutterError(code: "route_parse_failed", message: String(describing: err), details: nil))
    } catch {
      result(FlutterError(code: "ferrostar_error", message: "\(error)", details: nil))
    }
  }

  private static func updateLocation(args: Any?, result: @escaping FlutterResult) {
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String,
          let locDict = dict["location"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "updateLocation: bad args", details: nil))
      return
    }
    guard let entry = ControllerRegistry.shared.get(id) else {
      result(FlutterError(code: "unknown_controller", message: id, details: nil))
      return
    }
    do {
      let loc = try Serialization.decodeUserLocation(locDict)
      let newState: NavState
      if let last = entry.lastState {
        newState = entry.controller.updateUserLocation(location: loc, state: last)
      } else {
        newState = entry.controller.getInitialState(location: loc)
      }

      ControllerRegistry.shared.update(id) { e in
        e.lastState = newState
      }

      let tripState = newState.tripState
      var isOffRoute = false
      var spokenInstr: SpokenInstruction? = nil
      var deviationM: Double? = nil

      if case .navigating(_, _, _, _, _, _, _, let deviation, _, let spoken, _) = tripState {
        if case .offRoute(let m) = deviation {
          isOffRoute = true
          deviationM = m
        }
        spokenInstr = spoken
      }

      if let sink = entry.stateSink {
        sink(Serialization.encodeNavigationState(tripState, isOffRoute: isOffRoute))
      }
      if let spokenSink = entry.spokenSink, let s = spokenInstr {
        spokenSink(Serialization.encodeSpokenInstruction(s))
      }
      if let devSink = entry.deviationSink, let m = deviationM {
        devSink(Serialization.encodeDeviation(deviationMeters: m, durationMs: 0, location: loc))
      }

      result(nil)
    } catch {
      result(FlutterError(code: "invalid_argument", message: "\(error)", details: nil))
    }
  }

  private static func replaceRoute(args: Any?, result: @escaping FlutterResult) {
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String,
          let osrm = dict["osrm_json"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "replaceRoute: bad args", details: nil))
      return
    }
    guard let entry = ControllerRegistry.shared.get(id) else {
      result(FlutterError(code: "unknown_controller", message: id, details: nil))
      return
    }
    do {
      let route = try createRouteFromOsrm(
        routeData: try extractRouteData(from: osrm),
        waypointData: try extractWaypointData(from: osrm),
        polylinePrecision: 6
      )
      let newController = createNavigator(route: route, config: entry.config, shouldRecord: false)
      let newEntry = ControllerRegistry.Entry(controller: newController, config: entry.config)
      newEntry.stateSink = entry.stateSink
      newEntry.spokenSink = entry.spokenSink
      newEntry.deviationSink = entry.deviationSink
      ControllerRegistry.shared.replace(id, with: newEntry)
      result(nil)
    } catch {
      result(FlutterError(code: "route_parse_failed", message: "\(error)", details: nil))
    }
  }

  private static func extractRouteData(from osrm: [String: Any]) throws -> Data {
    if let routes = osrm["routes"] as? [[String: Any]], let route = routes.first {
      return try JSONSerialization.data(withJSONObject: route)
    }

    if osrm["legs"] != nil, osrm["geometry"] != nil {
      return try JSONSerialization.data(withJSONObject: osrm)
    }

    throw Serialization.SerializationError.missingField("routes[0]")
  }

  private static func extractWaypointData(from osrm: [String: Any]) throws -> Data {
    guard let waypoints = osrm["waypoints"] as? [[String: Any]] else {
      throw Serialization.SerializationError.missingField("waypoints")
    }
    return try JSONSerialization.data(withJSONObject: waypoints)
  }

  private static func dispose(args: Any?, result: @escaping FlutterResult) {
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String else {
      result(FlutterError(code: "invalid_argument", message: "dispose: bad args", details: nil))
      return
    }
    ControllerRegistry.shared.remove(id)
    result(nil)
  }
}
