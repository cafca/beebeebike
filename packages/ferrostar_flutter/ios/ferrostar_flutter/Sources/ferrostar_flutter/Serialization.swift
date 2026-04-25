import Foundation
import FerrostarCore
import FerrostarCoreFFI

enum Serialization {

  // MARK: UserLocation (Dart -> Swift)

  static func decodeUserLocation(_ dict: [String: Any]) throws -> UserLocation {
    guard let lat = dict["lat"] as? Double,
          let lng = dict["lng"] as? Double,
          let acc = dict["horizontal_accuracy_m"] as? Double,
          let tsMs = dict["timestamp_ms"] as? Int else {
      throw SerializationError.missingField("lat/lng/horizontal_accuracy_m/timestamp_ms")
    }
    // CLLocation course is -1 when heading is unknown; clamp negatives to nil
    // and finite >360 values into wrap range. UInt16 init traps on negative or
    // out-of-range Double, so this guard is load-bearing.
    let course: CourseOverGround? = (dict["course_deg"] as? Double).flatMap {
      guard $0.isFinite, $0 >= 0 else { return nil }
      let deg = UInt16(min($0.truncatingRemainder(dividingBy: 360), 359))
      return CourseOverGround(degrees: deg, accuracy: nil)
    }
    let speed: Speed? = (dict["speed_mps"] as? Double).map {
      Speed(value: $0, accuracy: nil)
    }
    return UserLocation(
      coordinates: GeographicCoordinate(lat: lat, lng: lng),
      horizontalAccuracy: acc,
      courseOverGround: course,
      timestamp: Date(timeIntervalSince1970: Double(tsMs) / 1000),
      speed: speed
    )
  }

  // MARK: NavigationState (Swift -> Dart)

  static func encodeNavigationState(_ tripState: TripState, isOffRoute: Bool) -> [String: Any?] {
    switch tripState {
    case .idle:
      return [
        "status": "idle",
        "is_off_route": false,
        "snapped_location": nil,
        "progress": nil,
        "current_visual": nil,
        "current_step": nil,
      ]
    case .complete:
      return [
        "status": "complete",
        "is_off_route": false,
        "snapped_location": nil,
        "progress": nil,
        "current_visual": nil,
        "current_step": nil,
      ]
    case .navigating(_, _, let snapped, let steps, _, let progress, _, _, let visual, _, _):
      return [
        "status": "navigating",
        "is_off_route": isOffRoute,
        "snapped_location": encodeUserLocation(snapped),
        "progress": encodeTripProgress(progress),
        "current_visual": encodeVisualInstruction(visual),
        "current_step": steps.first.map { encodeStepRef(step: $0) },
      ]
    }
  }

  static func encodeUserLocation(_ loc: UserLocation) -> [String: Any?] {
    return [
      "lat": loc.coordinates.lat,
      "lng": loc.coordinates.lng,
      "horizontal_accuracy_m": loc.horizontalAccuracy,
      "course_deg": loc.courseOverGround.map { Double($0.degrees) },
      "speed_mps": loc.speed?.value,
      "timestamp_ms": Int(loc.timestamp.timeIntervalSince1970 * 1000),
    ]
  }

  static func encodeTripProgress(_ p: TripProgress) -> [String: Any?] {
    // Int(Double) traps on NaN/Inf/overflow with EXC_BREAKPOINT — observed in
    // prod when ferrostar emits a degenerate first progress tick at session
    // start. Coerce to 0 so the Dart side falls back to "—" / loading state.
    // Bound at ~31 years of seconds before multiplying — covers any sane
    // routing duration and stays well within Int64 after *1000.
    let durMs: Int
    if p.durationRemaining.isFinite, abs(p.durationRemaining) < 1e9 {
      durMs = Int(p.durationRemaining * 1000)
    } else {
      durMs = 0
    }
    return [
      "distance_to_next_maneuver_m": p.distanceToNextManeuver.isFinite ? p.distanceToNextManeuver : 0,
      "distance_remaining_m": p.distanceRemaining.isFinite ? p.distanceRemaining : 0,
      "duration_remaining_ms": durMs,
    ]
  }

  static func encodeVisualInstruction(_ v: VisualInstruction?) -> [String: Any?]? {
    guard let v = v else { return nil }
    return [
      "primary_text": v.primaryContent.text,
      "secondary_text": v.secondaryContent?.text,
      "maneuver_type": maneuverTypeString(v.primaryContent.maneuverType),
      "maneuver_modifier": maneuverModifierString(v.primaryContent.maneuverModifier),
      "trigger_distance_m": v.triggerDistanceBeforeManeuver,
    ]
  }

  static func encodeStepRef(step: RouteStep) -> [String: Any?] {
    return ["road_name": step.roadName]
  }

  // MARK: SpokenInstruction (Swift -> Dart)

  static func encodeSpokenInstruction(_ s: SpokenInstruction) -> [String: Any?] {
    return [
      "uuid": s.utteranceId.uuidString,
      "text": s.text,
      "ssml": s.ssml,
      "trigger_distance_m": s.triggerDistanceBeforeManeuver,
      "emitted_at_ms": Int(Date().timeIntervalSince1970 * 1000),
    ]
  }

  // MARK: RouteDeviation (Swift -> Dart)

  static func encodeDeviation(deviationMeters: Double, durationMs: Int, location: UserLocation) -> [String: Any?] {
    return [
      "deviation_m": deviationMeters,
      "duration_off_route_ms": durationMs,
      "user_location": encodeUserLocation(location),
    ]
  }

  // MARK: ManeuverType / ManeuverModifier

  private static func maneuverTypeString(_ t: ManeuverType?) -> String {
    guard let t = t else { return "unknown" }
    switch t {
    case .turn: return "turn"
    case .newName: return "new name"
    case .depart: return "depart"
    case .arrive: return "arrive"
    case .merge: return "merge"
    case .onRamp: return "on ramp"
    case .offRamp: return "off ramp"
    case .fork: return "fork"
    case .endOfRoad: return "end of road"
    case .continue: return "continue"
    case .roundabout: return "roundabout"
    case .rotary: return "rotary"
    case .roundaboutTurn: return "roundabout turn"
    case .notification: return "notification"
    case .exitRoundabout: return "exit roundabout"
    case .exitRotary: return "exit rotary"
    }
  }

  private static func maneuverModifierString(_ m: ManeuverModifier?) -> String? {
    guard let m = m else { return nil }
    switch m {
    case .uTurn: return "uturn"
    case .sharpRight: return "sharp right"
    case .right: return "right"
    case .slightRight: return "slight right"
    case .straight: return "straight"
    case .slightLeft: return "slight left"
    case .left: return "left"
    case .sharpLeft: return "sharp left"
    }
  }

  enum SerializationError: Error {
    case missingField(String)
  }
}

extension Serialization {
  static func decodeWaypoint(_ dict: [String: Any]) throws -> Waypoint {
    guard let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double else {
      throw SerializationError.missingField("lat/lng")
    }
    let kindStr = (dict["kind"] as? String) ?? "break"
    let kind: WaypointKind = (kindStr == "via_point") ? .via : .break
    return Waypoint(
      coordinate: GeographicCoordinate(lat: lat, lng: lng),
      kind: kind
    )
  }

  static func decodeConfig(_ dict: [String: Any]) throws -> NavigationControllerConfig {
    let devM = (dict["deviation_threshold_m"] as? Double) ?? 50.0
    let snap = (dict["snap_user_location_to_route"] as? Bool) ?? true
    return NavigationControllerConfig(
      waypointAdvance: .waypointWithinRange(35.0),
      stepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: 10, minimumHorizontalAccuracy: 32),
      arrivalStepAdvanceCondition: stepAdvanceManual(),
      routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 25, maxAcceptableDeviation: devM),
      snappedLocationCourseFiltering: snap ? .snapToRoute : .raw
    )
  }
}
