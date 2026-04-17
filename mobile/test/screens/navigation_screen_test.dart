import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows live instruction and distance from NavigationState',
      (tester) async {
    const fakeState = NavigationState(
      status: TripStatus.navigating,
      isOffRoute: false,
      currentVisual: VisualInstruction(
        primaryText: 'Turn left onto Test Street',
        maneuverType: 'turn',
        maneuverModifier: 'left',
        triggerDistanceM: 150,
      ),
      progress: TripProgress(
        distanceToNextManeuverM: 150,
        distanceRemainingM: 3200,
        durationRemainingMs: 720000,
      ),
    );

    final fakeService = NavigationService(
      createController: (_, __) => throw UnimplementedError(),
      loadNavigationRoute: ({required origin, required destination}) =>
          throw UnimplementedError(),
      locationStream: const Stream.empty(),
      speakInstruction: (_) async {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          navigationStateProvider
              .overrideWith((ref) => Stream.value(fakeState)),
          navigationServiceProvider.overrideWithValue(fakeService),
        ],
        child: const MaterialApp(home: NavigationScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Turn left onto Test Street'), findsOneWidget);
    expect(find.text('150 m'), findsOneWidget);
  });
}
