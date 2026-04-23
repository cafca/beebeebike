import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/tts_toggle_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: child)),
      );

  testWidgets('renders volume_up icon when enabled', (tester) async {
    await tester.pumpWidget(wrap(TtsToggleFab(enabled: true, onTap: () {})));
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    expect(find.byIcon(Icons.volume_off), findsNothing);
  });

  testWidgets('renders volume_off icon when disabled', (tester) async {
    await tester.pumpWidget(wrap(TtsToggleFab(enabled: false, onTap: () {})));
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
  });

  testWidgets('fires onTap when tapped', (tester) async {
    var taps = 0;
    await tester
        .pumpWidget(wrap(TtsToggleFab(enabled: true, onTap: () => taps++)));
    await tester.tap(find.byType(TtsToggleFab));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
