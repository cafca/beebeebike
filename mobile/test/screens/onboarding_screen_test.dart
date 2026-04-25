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

  testWidgets('last slide shows register, login and skip actions',
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

    expect(find.byKey(const ValueKey('onboarding-register')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-login')), findsOneWidget);
    expect(find.byKey(const ValueKey('onboarding-skip')), findsOneWidget);
    expect(container.read(onboardingCompletedProvider), isFalse);
    expect(prefs.getBool('onboarding.completed.v1'), isNull);
  });

  testWidgets('tapping skip completes onboarding', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    final skip = find.byKey(const ValueKey('onboarding-skip'));
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(prefs.getBool('onboarding.completed.v1'), isTrue);
  });

  testWidgets('successful login completes onboarding', (tester) async {
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

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-login')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('login_email')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('login_password')), 'hunter2');
    await tester.tap(find.byKey(const Key('login_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(container.read(onboardingCompletedProvider), isTrue);
    expect(prefs.getBool('onboarding.completed.v1'), isTrue);
  });

  testWidgets('successful registration completes onboarding',
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

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-register')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('register_email')), 'new@example.com');
    await tester.enterText(
        find.byKey(const Key('register_password')), 'hunter2hunter2');
    await tester.tap(find.byKey(const Key('register_submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
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

    const expected = kAlwaysShowOnboarding ? isFalse : isTrue;
    expect(container.read(onboardingCompletedProvider), expected);
  });
}
