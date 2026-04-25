import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/widgets/paint_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Align(alignment: Alignment.bottomCenter, child: child),
    ),
  );
}

void main() {
  testWidgets('renders 7 color chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: _wrap(const PaintSheet())),
    );
    for (final v in const [-7, -3, -1, 0, 1, 3, 7]) {
      expect(find.byKey(ValueKey('paint-chip-$v')), findsOneWidget);
    }
  });

  testWidgets('tapping a chip selects value and turns paint mode on',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _wrap(const PaintSheet()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('paint-chip-7')));
    await tester.pump();

    final state = container.read(brushControllerProvider);
    expect(state.value, 7);
    expect(state.paintMode, isTrue);
  });
}
