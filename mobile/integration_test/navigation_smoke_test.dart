import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:beebeebike/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and renders the map screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
