import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders text and spinner', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReroutingToast()),
    ));
    expect(find.text('Rerouting…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
