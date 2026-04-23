import 'package:beebeebike/providers/onboarding_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/screens/onboarding_screen.dart';
import 'package:beebeebike/widgets/onboarding_dots.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping through onboarding sets the completion flag',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();

    late ProviderContainer container;
    await tester.pumpWidget(
      buildTestWidget(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return const OnboardingScreen();
          },
        ),
        prefs: prefs,
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isFalse);
    expect(find.byType(OnboardingDots), findsOneWidget);
    expect(find.text('Paint your favourite routes'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('What we store'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(
        find.text('Paint on the desktop, ride with your phone'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(prefs.getBool('onboarding.completed.v1'), isTrue);
  });

  testWidgets('provider respects the persisted flag on rebuild',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'onboarding.completed.v1': true});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    final expected = kAlwaysShowOnboarding ? isFalse : isTrue;
    expect(container.read(onboardingCompletedProvider), expected);
  });
}
