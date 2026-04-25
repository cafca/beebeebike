import 'package:ferrostar_flutter_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('E2EHome renders without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: E2EHome()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
