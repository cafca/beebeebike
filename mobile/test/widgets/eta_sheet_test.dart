import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/eta_sheet.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NavigationState _state() => const NavigationState(
      status: TripStatus.navigating,
      isOffRoute: false,
      progress: TripProgress(
        distanceToNextManeuverM: 120,
        distanceRemainingM: 1500,
        durationRemainingMs: 360000,
      ),
    );

void main() {
  testWidgets('close IconButton fires onClose', (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          onClose: () => closed++,
        ),
      ),
    ));
    final closeBtn = find.widgetWithIcon(IconButton, Icons.close);
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('does not render volume controls (moved to FAB)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          onClose: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.volume_up), findsNothing);
    expect(find.byIcon(Icons.volume_off), findsNothing);
  });

  testWidgets('shows loading fallback when navState is loading',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EtaSheet(
          navState: const AsyncValue.loading(),
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('Loading...'), findsOneWidget);
  });

  testWidgets('shows remaining distance from distanceRemainingM',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          onClose: () {},
        ),
      ),
    ));
    // _state() has distanceRemainingM: 1500, so expect "1.5 km"
    expect(find.text('1.5 km'), findsOneWidget);
  });
}
