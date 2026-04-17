import Foundation
#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterFramework)
import FlutterFramework
#endif
import FerrostarCore
import FerrostarCoreFFI

/// Owns native Navigator instances keyed by UUID string so Dart
/// can refer to them without sending the heavy underlying objects across the
/// method channel.
final class ControllerRegistry {
  static let shared = ControllerRegistry()

  final class Entry {
    let controller: Navigator
    let config: NavigationControllerConfig
    var stateSink: FlutterEventSink?
    var spokenSink: FlutterEventSink?
    var deviationSink: FlutterEventSink?
    var lastState: NavState?

    init(controller: Navigator, config: NavigationControllerConfig) {
      self.controller = controller
      self.config = config
    }
  }

  private let queue = DispatchQueue(label: "ferrostar_flutter.registry")
  private var entries: [String: Entry] = [:]

  func register(controller: Navigator, config: NavigationControllerConfig) -> String {
    let id = UUID().uuidString
    queue.sync {
      entries[id] = Entry(controller: controller, config: config)
    }
    return id
  }

  func get(_ id: String) -> Entry? { queue.sync { entries[id] } }

  func update(_ id: String, mutator: (Entry) -> Void) {
    queue.sync {
      if let e = entries[id] { mutator(e) }
    }
  }

  func replace(_ id: String, with entry: Entry) {
    queue.sync { entries[id] = entry }
  }

  @discardableResult
  func remove(_ id: String) -> Entry? { queue.sync { entries.removeValue(forKey: id) } }
}
