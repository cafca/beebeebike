import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kPrefDevModeUnlocked = 'dev.modeUnlocked';
const String kPrefPlaybackEnabled = 'dev.playbackEnabled';
const int kDevTapsRequired = 5;
const Duration kDevTapWindow = Duration(seconds: 3);

class TapUnlockCounter {
  TapUnlockCounter({
    required this.tapsRequired,
    required this.window,
    required this.onUnlock,
  });

  final int tapsRequired;
  final Duration window;
  final void Function() onUnlock;

  int _count = 0;
  Timer? _resetTimer;

  void tap() {
    _count++;
    _resetTimer?.cancel();
    if (_count >= tapsRequired) {
      _count = 0;
      onUnlock();
      return;
    }
    _resetTimer = Timer(window, () => _count = 0);
  }

  void dispose() {
    _resetTimer?.cancel();
  }
}

class DevModeController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefDevModeUnlocked) ?? false;
  }

  Future<void> setUnlocked(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefDevModeUnlocked, value);
    if (!value) {
      // Locking returns the app to a clean prod-equivalent state.
      await prefs.setBool(kPrefPlaybackEnabled, false);
    }
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? false;
    await setUnlocked(!current);
  }
}

final devModeProvider =
    AsyncNotifierProvider<DevModeController, bool>(DevModeController.new);

class PlaybackEnabledController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPrefPlaybackEnabled) ?? false;
  }

  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefPlaybackEnabled, value);
  }
}

final playbackEnabledProvider =
    AsyncNotifierProvider<PlaybackEnabledController, bool>(
        PlaybackEnabledController.new);
