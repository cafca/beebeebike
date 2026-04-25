/// Base class for all errors surfaced by the Ferrostar plugin.
///
/// Wraps a stable [code] string (matching the platform-channel error codes
/// emitted by the native side) and a human-readable [message]. Catch this to
/// handle every plugin-originated failure uniformly.
class FerrostarException implements Exception {
  /// Creates an exception with a platform-channel [code] and [message].
  FerrostarException(this.code, this.message);

  /// Stable identifier matching the native error code (e.g.
  /// `invalid_argument`, `route_parse_failed`). Suitable for programmatic
  /// dispatch.
  final String code;

  /// Human-readable description of what went wrong.
  final String message;
  @override
  String toString() => 'FerrostarException($code): $message';
}

/// Thrown when an argument fails validation on the native side (bad
/// coordinates, malformed config, etc.).
class InvalidArgumentException extends FerrostarException {
  /// Creates the exception with the explanatory [message].
  InvalidArgumentException(String message) : super('invalid_argument', message);
}

/// Thrown when an OSRM JSON payload could not be decoded into a route.
class RouteParseException extends FerrostarException {
  /// Creates the exception with the explanatory [message].
  RouteParseException(String message) : super('route_parse_failed', message);
}

/// Thrown when an operation references a controller id that has already been
/// disposed or never existed on the native side.
class UnknownControllerException extends FerrostarException {
  /// Creates the exception with the explanatory [message].
  UnknownControllerException(String message)
      : super('unknown_controller', message);
}

/// Thrown for unexpected internal errors from the Ferrostar core (bug,
/// invariant violation, OS-level failure). Should be rare in practice.
class FerrostarInternalException extends FerrostarException {
  /// Creates the exception with the explanatory [message].
  FerrostarInternalException(String message)
      : super('ferrostar_error', message);
}
