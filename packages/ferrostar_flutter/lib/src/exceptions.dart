class FerrostarException implements Exception {
  final String code;
  final String message;
  FerrostarException(this.code, this.message);
  @override
  String toString() => 'FerrostarException($code): $message';
}

class InvalidArgumentException extends FerrostarException {
  InvalidArgumentException(String message) : super('invalid_argument', message);
}

class RouteParseException extends FerrostarException {
  RouteParseException(String message) : super('route_parse_failed', message);
}

class UnknownControllerException extends FerrostarException {
  UnknownControllerException(String message) : super('unknown_controller', message);
}

class FerrostarInternalException extends FerrostarException {
  FerrostarInternalException(String message) : super('ferrostar_error', message);
}
