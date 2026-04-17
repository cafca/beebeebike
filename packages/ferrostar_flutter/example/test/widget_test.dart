import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ferrostar_flutter_example/main.dart';

void main() {
  testWidgets('E2EHome renders without error', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: E2EHome()));
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
