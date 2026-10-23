import 'package:beebeebike/screens/search_screen.dart';
import 'package:beebeebike/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  testWidgets('shows "Set home" row when no home saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestWidget(
      const SettingsScreen(),
      prefs: prefs,
      authenticated: true,
    ));
    await tester.pump();

    expect(find.text('Set home'), findsOneWidget);
    expect(find.text('Change home'), findsNothing);
  });

  testWidgets('shows "Change home" row when home is saved', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestWidget(
      const SettingsScreen(),
      prefs: prefs,
      authenticated: true,
      homeLocation: fakeHome(),
    ));
    await tester.pump();

    expect(find.text('Change home'), findsOneWidget);
    expect(find.text('Set home'), findsNothing);
  });

  testWidgets('tapping the row pushes SearchScreen in pickHome mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestWidget(
      const SettingsScreen(),
      prefs: prefs,
      authenticated: true,
    ));
    await tester.pump();

    await tester.tap(find.text('Set home'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
    expect(search.mode, SearchMode.pickHome);
  });

  testWidgets('shows success snackbar after picker returns a location',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(buildTestWidget(
      const SettingsScreen(),
      prefs: prefs,
      authenticated: true,
    ));
    await tester.pump();

    await tester.tap(find.text('Set home'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alexanderplatz'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Home set to'), findsOneWidget);
  });
}
