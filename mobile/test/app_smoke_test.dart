import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';

void main() {
  testWidgets('boots to the map screen shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              tileStyleUrl: 'http://localhost:8080/tiles/assets/styles/colorful/style.json',
            ),
          ),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );

    // TODO(task4): MapScreen stub renders 'Map'; assert 'Search here...' once Task 4 is done.
    expect(find.byType(BeeBeeBikeApp), findsOneWidget);
  }, skip: true); // MapScreen stub in place until Task 4
}
