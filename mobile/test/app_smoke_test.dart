import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/search_history_provider.dart';

void main() {
  testWidgets('boots to the map screen shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              apiBaseUrl: 'http://localhost:3000',
              tileStyleUrl: 'http://localhost:8080/tiles/assets/styles/colorful/style.json',
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const BeeBeeBikeApp(),
      ),
    );

    expect(find.text('Search here...'), findsOneWidget);
  });
}
