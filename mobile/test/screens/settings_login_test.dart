import 'package:beebeebike/screens/login_screen.dart';
import 'package:beebeebike/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen', () {
    testWidgets('shows Log in tile when anonymous (not authenticated)',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const SettingsScreen(),
          prefs: prefs,
          authenticated: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log in'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('Log in tile is enabled (tappable) when anonymous',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const SettingsScreen(),
          prefs: prefs,
          authenticated: false,
        ),
      );
      await tester.pumpAndSettle();

      final loginTap = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Log in'),
          matching: find.byType(InkWell),
        ),
      );
      expect(loginTap.onTap, isNotNull);
    });

    testWidgets('tapping Log in navigates to LoginScreen', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const SettingsScreen(),
          prefs: prefs,
          authenticated: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows Log out tile and email when authenticated',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const SettingsScreen(),
          prefs: prefs,
          authenticated: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
      expect(find.text(TestFixtures.loggedInUser['email'] as String),
          findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('renders email and password fields with correct keys',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const LoginScreen(),
          prefs: prefs,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_email')), findsOneWidget);
      expect(find.byKey(const Key('login_password')), findsOneWidget);
    });

    testWidgets('shows error message after failed login', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildTestWidget(
          const LoginScreen(),
          prefs: prefs,
          loginSucceeds: false,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('login_email')), 'wrong@example.com');
      await tester.enterText(
          find.byKey(const Key('login_password')), 'wrongpassword');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password'), findsOneWidget);
    });

    testWidgets('pops screen after successful login', (tester) async {
      final prefs = await SharedPreferences.getInstance();

      // Wrap LoginScreen in a navigator so we can verify the pop
      await tester.pumpWidget(
        buildTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Open Login'),
            ),
          ),
          prefs: prefs,
          loginSucceeds: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Login'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(
          find.byKey(const Key('login_email')), 'test@example.com');
      await tester.enterText(
          find.byKey(const Key('login_password')), 'password123');

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // LoginScreen should have been popped
      expect(find.byType(LoginScreen), findsNothing);
    });
  });
}
