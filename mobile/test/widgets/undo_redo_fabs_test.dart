import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/widgets/undo_redo_fabs.dart';

void main() {
  testWidgets('renders two FABs with correct keys', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Stack(
            children: [
              UndoRedoFabs(bottomOffset: 120),
            ],
          ),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('undo-fab')), findsOneWidget);
    expect(find.byKey(const ValueKey('redo-fab')), findsOneWidget);
  });
}
