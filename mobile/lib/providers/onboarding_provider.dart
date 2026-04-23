import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_history_provider.dart';

/// Flip to `true` locally to replay the onboarding flow on every launch
/// regardless of the persisted flag. Must stay `false` on committed code.
const kAlwaysShowOnboarding = false;

const _onboardingCompletedKey = 'onboarding.completed.v1';

final onboardingCompletedProvider =
    NotifierProvider<OnboardingController, bool>(OnboardingController.new);

class OnboardingController extends Notifier<bool> {
  @override
  bool build() {
    if (kAlwaysShowOnboarding) return false;
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> complete() async {
    state = true;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_onboardingCompletedKey, true);
  }
}
