import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Report a caught-but-unexpected error to GlitchTip (Sentry) with a stack
/// trace, plus debug-print it in debug builds. Use at sites where we want to
/// keep the existing UX (e.g. a snackbar, a retry, a fallback) but still need
/// visibility into failures in production.
///
/// `context` is a short stable identifier (e.g. `'nav.start'`) used as a
/// Sentry tag so related errors group together.
void reportError(
  Object error,
  StackTrace stackTrace, {
  required String context,
}) {
  if (kDebugMode) {
    debugPrint('$context error: $error\n$stackTrace');
  }
  Sentry.captureException(
    error,
    stackTrace: stackTrace,
    withScope: (scope) => scope.setTag('context', context),
  );
}
