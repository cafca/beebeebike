import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/route_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders duration and distance', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 12,
          distanceKm: 3.4,
          onStart: () {},
        ),
      ),
    ));
    expect(find.textContaining('12 min'), findsOneWidget);
    expect(find.textContaining('3.4 km'), findsOneWidget);
  });

  testWidgets('Start button fires onStart', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 12,
          distanceKm: 3.4,
          onStart: () => tapped++,
        ),
      ),
    ));
    await tester.tap(find.text('Start ride'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('close button hidden when onClose is null', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 12,
          distanceKm: 3.4,
          onStart: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('close button visible and fires onClose when provided',
      (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 12,
          distanceKm: 3.4,
          onStart: () {},
          onClose: () => closed++,
        ),
      ),
    ));
    expect(find.byIcon(Icons.close), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('heart button toggles saved icon state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 12,
          distanceKm: 3.4,
          onStart: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('data strip shows ETA hh:mm formatted from now', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RouteSummary(
          durationMinutes: 20,
          distanceKm: 5.0,
          onStart: () {},
        ),
      ),
    ));
    expect(find.textContaining(RegExp(r'ETA \d{2}:\d{2}')), findsOneWidget);
  });
}
