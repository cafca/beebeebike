import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/dev/dev_mode.dart';

void main() {
  group('TapUnlockCounter', () {
    test('5 taps within 3 s fires once', () {
      fakeAsync((async) {
        var fired = 0;
        final c = TapUnlockCounter(
          tapsRequired: 5,
          window: const Duration(seconds: 3),
          onUnlock: () => fired++,
        );
        for (var i = 0; i < 5; i++) {
          c.tap();
          async.elapse(const Duration(milliseconds: 200));
        }
        expect(fired, 1);
      });
    });

    test('4 taps then 4 s gap then 1 tap does not fire', () {
      fakeAsync((async) {
        var fired = 0;
        final c = TapUnlockCounter(
          tapsRequired: 5,
          window: const Duration(seconds: 3),
          onUnlock: () => fired++,
        );
        for (var i = 0; i < 4; i++) {
          c.tap();
          async.elapse(const Duration(milliseconds: 200));
        }
        async.elapse(const Duration(seconds: 4));
        c.tap();
        expect(fired, 0);
      });
    });

    test('counter resets after firing — second 5-tap series fires again', () {
      fakeAsync((async) {
        var fired = 0;
        final c = TapUnlockCounter(
          tapsRequired: 5,
          window: const Duration(seconds: 3),
          onUnlock: () => fired++,
        );
        for (var i = 0; i < 5; i++) {
          c.tap();
        }
        async.elapse(const Duration(milliseconds: 100));
        for (var i = 0; i < 5; i++) {
          c.tap();
        }
        expect(fired, 2);
      });
    });
  });
}
