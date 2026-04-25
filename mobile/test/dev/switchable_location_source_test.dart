import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/dev/switchable_location_source.dart';

UserLocation _u(double lng) => UserLocation(
      lat: 0,
      lng: lng,
      horizontalAccuracyM: 5,
      timestampMs: 0,
    );

void main() {
  group('SwitchableLocationSource', () {
    test('forwards real-source events while not playback', () async {
      final real = StreamController<UserLocation>.broadcast();
      final playback = StreamController<UserLocation>.broadcast();
      final source = SwitchableLocationSource(
        usePlayback: () => false,
        realStream: () => real.stream,
        playbackStream: () => playback.stream,
      );
      final got = <UserLocation>[];
      final sub = source.stream.listen(got.add);
      real.add(_u(1));
      await Future<void>.delayed(Duration.zero);
      expect(got.map((u) => u.lng), [1]);
      await sub.cancel();
      source.dispose();
      await real.close();
      await playback.close();
    });

    test('switches to playback events when notifySourceChanged()', () async {
      final real = StreamController<UserLocation>.broadcast();
      final playback = StreamController<UserLocation>.broadcast();
      var usePlayback = false;
      final source = SwitchableLocationSource(
        usePlayback: () => usePlayback,
        realStream: () => real.stream,
        playbackStream: () => playback.stream,
      );
      final got = <UserLocation>[];
      final sub = source.stream.listen(got.add);
      real.add(_u(1));
      await Future<void>.delayed(Duration.zero);
      usePlayback = true;
      source.notifySourceChanged();
      playback.add(_u(2));
      await Future<void>.delayed(Duration.zero);
      expect(got.map((u) => u.lng), [1, 2]);
      await sub.cancel();
      source.dispose();
      await real.close();
      await playback.close();
    });

    test('after switch, ignores events from previous source', () async {
      final real = StreamController<UserLocation>.broadcast();
      final playback = StreamController<UserLocation>.broadcast();
      var usePlayback = false;
      final source = SwitchableLocationSource(
        usePlayback: () => usePlayback,
        realStream: () => real.stream,
        playbackStream: () => playback.stream,
      );
      final got = <UserLocation>[];
      final sub = source.stream.listen(got.add);
      usePlayback = true;
      source.notifySourceChanged();
      real.add(_u(99));
      await Future<void>.delayed(Duration.zero);
      expect(got, isEmpty);
      await sub.cancel();
      source.dispose();
      await real.close();
      await playback.close();
    });
  });
}
