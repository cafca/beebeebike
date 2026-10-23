import 'dart:async';

import 'package:ferrostar_flutter/ferrostar_flutter.dart';

class SwitchableLocationSource {
  SwitchableLocationSource({
    required this.usePlayback,
    required this.realStream,
    required this.playbackStream,
  }) {
    _resubscribe();
  }

  final bool Function() usePlayback;
  final Stream<UserLocation> Function() realStream;
  final Stream<UserLocation> Function() playbackStream;

  final _out = StreamController<UserLocation>.broadcast();
  StreamSubscription<UserLocation>? _sub;

  Stream<UserLocation> get stream => _out.stream;

  void notifySourceChanged() => _resubscribe();

  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(_out.close());
  }

  void _resubscribe() {
    unawaited(_sub?.cancel());
    final src = usePlayback() ? playbackStream() : realStream();
    _sub = src.listen(_out.add, onError: _out.addError);
  }
}
