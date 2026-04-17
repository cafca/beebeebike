import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

void main() {
  test('speakInstruction calls FlutterTts.speak with the given text', () async {
    final mockTts = MockFlutterTts();
    when(() => mockTts.speak(any())).thenAnswer((_) async => 1);

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost',
            tileStyleUrl: 'http://localhost/tiles',
          ),
        ),
        flutterTtsProvider.overrideWithValue(mockTts),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(navigationServiceProvider);
    await service.speakInstruction('Turn left');

    verify(() => mockTts.speak('Turn left')).called(1);
  });
}
