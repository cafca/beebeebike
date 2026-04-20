import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';

/// Opens a chunked-byte stream for the SSE endpoint. Split out so tests can
/// inject a fake without touching Dio or real sockets. The client must be
/// able to cancel an in-flight open via [cancelToken] and to notice stream
/// errors so the reconnect loop can run.
typedef RatingEventsOpener = Future<Stream<List<int>>> Function({
  required CancelToken cancelToken,
});

/// Parsed SSE frame. The server only emits `event: invalidate` today, but we
/// keep both fields to aid debugging and future extension.
@immutable
class SseEvent {
  const SseEvent({required this.event, required this.data});
  final String event;
  final String data;
}

/// Pure-Dart SSE parser. Handles the subset of the spec the backend emits:
///   - UTF-8 encoded
///   - LF or CRLF line endings
///   - `event:` / `data:` fields, blank-line dispatch
///   - `:` comments (keepalives) ignored
///   - `id:` / `retry:` accepted but unused
///
/// We deliberately ignore retry-hints from the server; reconnect pacing is
/// owned by [RatingEventsClient.backoff] so the kill switch stays the only
/// thing controlling reconnect cadence.
Stream<SseEvent> parseSseStream(Stream<List<int>> bytes) async* {
  final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
  String? eventType;
  final dataBuf = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (eventType != null || dataBuf.isNotEmpty) {
        yield SseEvent(
          event: eventType ?? 'message',
          data: dataBuf.toString(),
        );
      }
      eventType = null;
      dataBuf.clear();
      continue;
    }
    if (line.startsWith(':')) continue; // comment (keepalive)
    final colon = line.indexOf(':');
    final String field;
    String value;
    if (colon == -1) {
      field = line;
      value = '';
    } else {
      field = line.substring(0, colon);
      value = line.substring(colon + 1);
      if (value.startsWith(' ')) value = value.substring(1);
    }
    switch (field) {
      case 'event':
        eventType = value;
        break;
      case 'data':
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(value);
        break;
      default:
        break; // id / retry / unknown fields
    }
  }
  // If the stream ended mid-event (no terminating blank line) we drop the
  // partial record — the reconnect loop forces an invalidate on the next
  // successful connect anyway.
}

void _log(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Listens to `/api/ratings/events` and invokes [onInvalidate] whenever the
/// user's painted areas change on any device. Also fires [onInvalidate] once
/// on every successful (re)connect — after a gap we can't tell whether we
/// missed events, so we treat the reconnect itself as a possible miss. The
/// client-side response is idempotent (refetch viewport), so the extra call
/// is cheap.
///
/// Kill switches:
///   1. Server flag off → backend returns 404 for this route. The client
///      latches [serverDisabled] = true, stops reconnecting, and the
///      controller falls back to camera-idle polling.
///   2. Client flag off → `RatingEventsClient` is never constructed (see
///      `RatingOverlayController.attach`).
///
/// Both ends of the kill switch are intentionally independent: flipping
/// either one is enough to stop the push traffic without a deploy coupling.
class RatingEventsClient {
  RatingEventsClient({
    required this.opener,
    required this.onInvalidate,
    Duration Function(int attempt)? backoff,
    // Hook for tests to pump the event loop; real code uses Future.delayed.
    Future<void> Function(Duration)? sleep,
  })  : backoff = backoff ?? _defaultBackoff,
        _sleep = sleep ?? Future.delayed;

  final RatingEventsOpener opener;
  final VoidCallback onInvalidate;
  final Duration Function(int attempt) backoff;
  final Future<void> Function(Duration) _sleep;

  CancelToken? _cancel;
  Completer<void>? _wake;
  StreamSubscription<SseEvent>? _subscription;
  Completer<void>? _consumeDone;
  bool _stopped = false;
  bool _serverDisabled = false;
  int _attempts = 0;
  Future<void>? _loop;

  /// True once the server has answered 404 — meaning SSE is disabled backend
  /// side. Caller uses this as a signal to stop trying to restart the client.
  bool get serverDisabled => _serverDisabled;

  /// True while the reconnect loop is active.
  bool get isRunning => _loop != null && !_stopped;

  /// Start the listen loop. Idempotent — a second call while already running
  /// is a no-op. Does nothing if [stop] has already been called or if the
  /// server disabled the feature on a previous connect.
  void start() {
    if (_stopped || _serverDisabled || _loop != null) return;
    _loop = _run();
  }

  /// Stop the listen loop, cancel any in-flight connect, and break out of
  /// any current backoff sleep. Safe to call multiple times. The returned
  /// future completes when the loop has actually exited, which callers can
  /// await during widget dispose to avoid leaked tasks.
  Future<void> stop() async {
    _stopped = true;
    _cancel?.cancel();
    _cancel = null;
    // Cancel any active SSE subscription so an idle `await for` on the
    // parser stream can unwind even when the opener didn't honor the
    // CancelToken (e.g. in-memory fakes).
    final sub = _subscription;
    _subscription = null;
    if (sub != null) {
      // `cancel()` may return a Future that completes when the underlying
      // HTTP stream finishes draining; don't block `stop()` on it.
      unawaited(sub.cancel());
    }
    // Complete the consume-done completer so `_consume` unblocks even on
    // a cancel path — `onDone` is not called for user cancellation, so
    // waiting on it alone would hang.
    final cd = _consumeDone;
    _consumeDone = null;
    if (cd != null && !cd.isCompleted) cd.complete();
    final wake = _wake;
    _wake = null;
    if (wake != null && !wake.isCompleted) wake.complete();
    final loop = _loop;
    _loop = null;
    if (loop != null) await loop;
  }

  Future<void> _run() async {
    while (!_stopped && !_serverDisabled) {
      final token = CancelToken();
      _cancel = token;
      Stream<List<int>>? bytes;
      try {
        bytes = await opener(cancelToken: token);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e) || _stopped) return;
        if (e.response?.statusCode == 404) {
          _log('rating-events: server returned 404, disabling client');
          _serverDisabled = true;
          return;
        }
        _log('rating-events: connect failed: ${e.message}');
      } catch (e) {
        if (_stopped) return;
        _log('rating-events: connect failed: $e');
      }

      if (_stopped) return;

      if (bytes != null) {
        _attempts = 0;
        _log('rating-events: connected');
        // Force-invalidate on every (re)connect. We might have missed events
        // during the gap; the controller's response is idempotent so a
        // redundant refetch is cheap insurance.
        try {
          onInvalidate();
        } catch (e) {
          _log('rating-events: onInvalidate threw on connect: $e');
        }
        await _consume(bytes);
        if (_stopped || _serverDisabled) return;
      }

      if (_stopped || _serverDisabled) return;

      final delay = backoff(++_attempts);
      _log('rating-events: backoff ${delay.inMilliseconds}ms '
          '(attempt $_attempts)');
      final wake = Completer<void>();
      _wake = wake;
      await Future.any([_sleep(delay), wake.future]);
      _wake = null;
    }
  }

  /// Consume the SSE stream via an explicit subscription so [stop] can
  /// cancel the listen even when the underlying stream is in-memory (e.g.
  /// tests) and doesn't honor the Dio CancelToken.
  Future<void> _consume(Stream<List<int>> bytes) async {
    final done = Completer<void>();
    _consumeDone = done;
    final sub = parseSseStream(bytes).listen(
      (ev) {
        if (_stopped) return;
        if (ev.event == 'invalidate') {
          try {
            onInvalidate();
          } catch (e) {
            _log('rating-events: onInvalidate threw: $e');
          }
        }
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.complete();
        if (!_stopped) _log('rating-events: stream error: $e');
      },
      cancelOnError: true,
    );
    _subscription = sub;
    try {
      await done.future;
    } finally {
      if (identical(_subscription, sub)) _subscription = null;
      if (identical(_consumeDone, done)) _consumeDone = null;
      // Fire-and-forget the cancel. Awaiting it can hang when the upstream
      // stream still has buffered events — the reconnect loop only needs
      // the listen callback to stop firing, which cancel accomplishes
      // synchronously from our perspective.
      unawaited(sub.cancel());
    }
    if (!_stopped) _log('rating-events: stream closed, will reconnect');
  }
}

/// Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (capped). Matches the
/// budget we'd be willing to stall before falling back to camera-idle
/// polling — any longer and the user probably won't notice the difference.
Duration _defaultBackoff(int attempt) {
  final a = attempt.clamp(1, 6);
  final seconds = (1 << (a - 1)).clamp(1, 30);
  return Duration(seconds: seconds);
}

/// Factory keyed on [onInvalidate] — the controller holds the callback, the
/// provider builds a client wrapped around the shared [Dio]. Overridden in
/// tests to return a fake client that records start/stop and drives
/// invalidations synchronously.
typedef RatingEventsClientFactory = RatingEventsClient Function(
  VoidCallback onInvalidate,
);

final ratingEventsClientFactoryProvider =
    Provider<RatingEventsClientFactory>((ref) {
  final dio = ref.watch(dioProvider);
  return (onInvalidate) => RatingEventsClient(
        opener: ({required cancelToken}) async {
          final response = await dio.get<ResponseBody>(
            '/api/ratings/events',
            options: Options(
              responseType: ResponseType.stream,
              headers: const {
                'Accept': 'text/event-stream',
                'Cache-Control': 'no-cache',
              },
              // SSE is long-lived; receive-timeout would kill healthy
              // connections. `Duration.zero` disables it in Dio.
              receiveTimeout: Duration.zero,
            ),
            cancelToken: cancelToken,
          );
          final body = response.data;
          if (body == null) {
            throw StateError('rating-events: null response body');
          }
          // `body.stream` is Stream<Uint8List>; parser accepts any byte stream.
          return body.stream.cast<List<int>>();
        },
        onInvalidate: onInvalidate,
      );
});
