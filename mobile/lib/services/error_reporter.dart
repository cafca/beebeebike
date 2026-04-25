import 'dart:async';

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
  unawaited(Sentry.captureException(
    error,
    stackTrace: stackTrace,
    withScope: (scope) => scope.setTag('context', context),
  ));
}

/// Record a breadcrumb attached to subsequent Sentry events, and mirror it to
/// `debugPrint` in debug builds. Use for high-frequency, non-actionable events
/// (e.g. transient TTS failures) so they provide context when a real error
/// lands without becoming their own GlitchTip issues.
void addBreadcrumb(String message, {String? category}) {
  if (kDebugMode) debugPrint('${category ?? "breadcrumb"}: $message');
  unawaited(Sentry.addBreadcrumb(
    Breadcrumb(message: message, category: category, level: SentryLevel.info),
  ));
}
