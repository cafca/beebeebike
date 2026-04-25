import 'dart:async';
import 'dart:convert';

import 'package:beebeebike/services/rating_events_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// ---- Helpers ---------------------------------------------------------------

List<int> _bytes(String s) => utf8.encode(s);

/// Give the event loop time to flush the stream-transformer pipeline,
/// the reconnect loop's awaited futures, and any pending microtasks.
Future<void> _pump([Duration? d]) =>
    Future<void>.delayed(d ?? const Duration(milliseconds: 20));

void main() {
  group('parseSseStream', () {
    test('emits a single event with default type and data', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('data: hello\n\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events, hasLength(1));
      expect(events.first.event, 'message');
      expect(events.first.data, 'hello');
    });

    test('preserves custom event type', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('event: invalidate\ndata: {}\n\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events.single.event, 'invalidate');
      expect(events.single.data, '{}');
    });

    test('concatenates multi-line data with newline separator', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('data: one\ndata: two\n\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events.single.data, 'one\ntwo');
    });

    test('ignores comment lines (keepalives)', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes(': keepalive\n\nevent: invalidate\ndata: {}\n\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events, hasLength(1));
      expect(events.single.event, 'invalidate');
    });

    test('handles CRLF line endings', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('event: invalidate\r\ndata: {}\r\n\r\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events.single.event, 'invalidate');
      expect(events.single.data, '{}');
    });

    test('handles frames split across byte chunks', () async {
      // Frame split mid-event-name, mid-value and across the dispatch blank
      // line — simulates real TCP chunking.
      final chunks = [
        _bytes('event: inv'),
        _bytes('alidate\nda'),
        _bytes('ta: {"user_id":"abc'),
        _bytes('"}\n'),
        _bytes('\n'),
      ];
      final input = Stream<List<int>>.fromIterable(chunks);
      final events = await parseSseStream(input).toList();
      expect(events.single.event, 'invalidate');
      expect(events.single.data, '{"user_id":"abc"}');
    });

    test('ignores unknown fields like id and retry', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('id: 42\nretry: 5000\nevent: invalidate\ndata: {}\n\n'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events.single.event, 'invalidate');
    });

    test('drops trailing partial frame with no blank line', () async {
      final input = Stream<List<int>>.fromIterable([
        _bytes('event: invalidate\ndata: {}'),
      ]);
      final events = await parseSseStream(input).toList();
      expect(events, isEmpty,
          reason: 'no blank line means the frame was never dispatched');
    });
  });

  group('RatingEventsClient', () {
    test('fires onInvalidate once per event plus once on connect',
        () async {
      var calls = 0;
      final controller = StreamController<List<int>>();
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async => controller.stream,
        onInvalidate: () => calls++,
        // Zero backoff — we shouldn't reach it here anyway.
        backoff: (_) => Duration.zero,
        sleep: (_) async {},
      )..start();
      await _pump();
      expect(calls, 1, reason: 'force-invalidate on first connect');

      controller.add(_bytes('event: invalidate\ndata: {}\n\n'));
      await _pump();
      expect(calls, 2);

      controller.add(_bytes('event: invalidate\ndata: {}\n\n'));
      await _pump();
      expect(calls, 3);

      await client.stop();
      await controller.close();
    });

    test('ignores non-invalidate events', () async {
      var calls = 0;
      final controller = StreamController<List<int>>();
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async => controller.stream,
        onInvalidate: () => calls++,
        sleep: (_) async {},
      )..start();
      await _pump();
      final baseline = calls; // 1 (force-invalidate on connect)

      controller
        ..add(_bytes('event: keepalive\ndata: ok\n\n'))
        ..add(_bytes('data: plain message\n\n'));
      await _pump();
      expect(calls, baseline, reason: 'only invalidate events count');

      await client.stop();
      await controller.close();
    });

    test('reconnects and fires force-invalidate again when stream closes',
        () async {
      var calls = 0;
      var opens = 0;
      StreamController<List<int>>? current;
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async {
          opens++;
          current = StreamController<List<int>>();
          return current!.stream;
        },
        onInvalidate: () => calls++,
        backoff: (_) => Duration.zero,
        sleep: (_) async {},
      )..start();
      await _pump();
      expect(opens, 1);
      expect(calls, 1, reason: 'force-invalidate on first connect');

      // Server drops the stream — expect reconnect + another force-invalidate.
      await current!.close();
      await _pump();
      expect(opens, 2);
      expect(calls, 2);

      await client.stop();
      await current!.close();
    });

    test('latches serverDisabled on 404 and stops retrying', () async {
      var opens = 0;
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async {
          opens++;
          throw DioException(
            requestOptions: RequestOptions(path: '/api/ratings/events'),
            response: Response(
              requestOptions: RequestOptions(path: '/api/ratings/events'),
              statusCode: 404,
            ),
            type: DioExceptionType.badResponse,
          );
        },
        onInvalidate: () {},
        // Fast path to detect any accidental retry.
        backoff: (_) => Duration.zero,
        sleep: (_) async {},
      )..start();
      await _pump();
      expect(client.serverDisabled, isTrue);
      expect(opens, 1, reason: '404 must not retry');

      // A second start is a no-op once serverDisabled latches.
      client.start();
      await _pump();
      expect(opens, 1);
    });

    test('backs off then reconnects after a transient connect error',
        () async {
      var opens = 0;
      final delays = <Duration>[];
      final sleepCompleter = <Completer<void>>[];
      StreamController<List<int>>? current;
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async {
          opens++;
          if (opens == 1) {
            throw DioException(
              requestOptions: RequestOptions(path: '/api/ratings/events'),
              type: DioExceptionType.connectionError,
              message: 'boom',
            );
          }
          current = StreamController<List<int>>();
          return current!.stream;
        },
        onInvalidate: () {},
        backoff: (attempt) => Duration(seconds: attempt),
        sleep: (d) {
          delays.add(d);
          final c = Completer<void>();
          sleepCompleter.add(c);
          return c.future;
        },
      )..start();
      await _pump();
      expect(opens, 1);
      expect(delays, [const Duration(seconds: 1)],
          reason: 'first failure schedules backoff');

      // Release the sleep — loop should reconnect.
      sleepCompleter.single.complete();
      await _pump();
      expect(opens, 2);
      expect(client.isRunning, isTrue);

      await client.stop();
      await current?.close();
    });

    test('stop cancels in-flight and breaks out of backoff', () async {
      final sleepCompleter = Completer<void>();
      final client = RatingEventsClient(
        opener: ({required cancelToken}) async {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/ratings/events'),
            type: DioExceptionType.connectionError,
          );
        },
        onInvalidate: () {},
        backoff: (_) => const Duration(hours: 1),
        sleep: (_) => sleepCompleter.future,
      )..start();
      await _pump();
      // Now in backoff sleep — stop() must unblock us.
      final stopFuture = client.stop();
      await stopFuture.timeout(const Duration(seconds: 2));
      expect(sleepCompleter.isCompleted, isFalse,
          reason: 'stop should not leak the sleep future — it breaks out '
              'via the wake completer');
      expect(client.isRunning, isFalse);
    });
  });
}
