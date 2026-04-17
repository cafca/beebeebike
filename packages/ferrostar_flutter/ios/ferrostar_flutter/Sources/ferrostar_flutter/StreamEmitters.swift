#if canImport(Flutter)
import Flutter
#elseif canImport(FlutterFramework)
import FlutterFramework
#endif

/// Registers one EventChannel per (controller_id, kind) tuple, capturing the
/// FlutterEventSink in the ControllerRegistry so native callbacks can dispatch
/// events to the right Dart stream.
final class StreamEmitters: NSObject {

  enum Kind { case state, spoken, deviation }

  static func register(
    controllerId: String,
    kind: Kind,
    messenger: FlutterBinaryMessenger
  ) {
    let base = "land._001/ferrostar_flutter"
    let name: String
    switch kind {
    case .state: name = "\(base)/state/\(controllerId)"
    case .spoken: name = "\(base)/spoken/\(controllerId)"
    case .deviation: name = "\(base)/deviation/\(controllerId)"
    }
    let channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    let handler = Handler(controllerId: controllerId, kind: kind)
    channel.setStreamHandler(handler)
  }

  final class Handler: NSObject, FlutterStreamHandler {
    let controllerId: String
    let kind: Kind
    init(controllerId: String, kind: Kind) {
      self.controllerId = controllerId
      self.kind = kind
    }

    func onListen(withArguments _: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
      ControllerRegistry.shared.update(controllerId) { entry in
        switch kind {
        case .state:
          entry.stateSink = eventSink
        case .spoken:
          entry.spokenSink = eventSink
        case .deviation:
          entry.deviationSink = eventSink
        }
      }
      return nil
    }

    func onCancel(withArguments _: Any?) -> FlutterError? {
      ControllerRegistry.shared.update(controllerId) { entry in
        switch kind {
        case .state:
          entry.stateSink = nil
        case .spoken:
          entry.spokenSink = nil
        case .deviation:
          entry.deviationSink = nil
        }
      }
      return nil
    }
  }
}
