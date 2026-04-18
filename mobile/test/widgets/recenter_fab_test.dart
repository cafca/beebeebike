import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders my_location icon and fires onTap when tapped',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecenterFab(onTap: () => tapped++)),
    ));

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    await tester.tap(find.byType(RecenterFab));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
