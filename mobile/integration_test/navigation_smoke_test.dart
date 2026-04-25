import 'dart:async';

import 'package:beebeebike/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'app launches and renders the map screen',
    (tester) async {
      unawaited(app.main());
      // MapLibre keeps frames coming, so pumpAndSettle can hang. Pump a
      // bounded number of frames instead and then assert the scaffold.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(Scaffold), findsWidgets);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
