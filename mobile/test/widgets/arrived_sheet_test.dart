import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Arrived headline and fires onDone when Done tapped',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ArrivedSheet(onDone: () => tapped++)),
    ));

    expect(find.text('Arrived'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
