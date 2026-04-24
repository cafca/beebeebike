import 'package:beebeebike/providers/onboarding_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/screens/onboarding_screen.dart';
import 'package:beebeebike/widgets/login_form.dart';
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

  testWidgets('last slide shows an inline login form', (tester) async {
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

    expect(find.byType(LoginForm), findsOneWidget);
    expect(find.byKey(const Key('login_email')), findsOneWidget);
    expect(find.byKey(const Key('login_password')), findsOneWidget);
    expect(container.read(onboardingCompletedProvider), isFalse);
    expect(prefs.getBool('onboarding.completed.v1'), isNull);
  });

  testWidgets('successful login on last slide completes onboarding',
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
        loginSucceeds: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login_email')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('login_password')), 'hunter2');
    await tester.tap(find.text('Log in'));
    // CircularProgressIndicator animates during _loading, so pumpAndSettle
    // would spin forever. Pump a single frame to let async work resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

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
