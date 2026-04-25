import 'package:beebeebike/dev/dev_mode.dart';
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  // Ensure the widget is in the visible viewport after scrolling.
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('version row visible; dev section hidden until unlocked',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(const SettingsScreen(), prefs: prefs),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const ValueKey('settings-version-row')));
    expect(find.byKey(const ValueKey('settings-version-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-dev-section')), findsNothing);
  });

  testWidgets('5 taps on version row unlocks dev section', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      buildTestWidget(const SettingsScreen(), prefs: prefs),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-version-row'));
    await _scrollTo(tester, row);
    for (var i = 0; i < 5; i++) {
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-dev-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-playback-toggle')),
        findsOneWidget);
  });

  testWidgets('toggling playback switch updates provider', (tester) async {
    SharedPreferences.setMockInitialValues({kPrefDevModeUnlocked: true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: testProviderOverrides(prefs: prefs),
    );
    addTearDown(container.dispose);
    // Pre-warm devModeProvider so it reads the mock prefs value (true).
    await container.read(devModeProvider.future);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates:
            AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('settings-playback-toggle'));
    await _scrollTo(tester, toggle);
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(playbackEnabledProvider).value, isTrue);
  });
}
