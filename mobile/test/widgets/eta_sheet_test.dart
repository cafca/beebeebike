import 'package:beebeebike/widgets/eta_sheet.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NavigationState _state() => const NavigationState(
      status: TripStatus.navigating,
      isOffRoute: false,
      progress: TripProgress(
        distanceToNextManeuverM: 120,
        distanceRemainingM: 1500,
        durationRemainingMs: 360000,
      ),
    );

void main() {
  testWidgets('close IconButton fires onClose', (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          ttsEnabled: true,
          onToggleTts: () {},
          onClose: () => closed++,
        ),
      ),
    ));
    final closeBtn = find.widgetWithIcon(IconButton, Icons.close);
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
    expect(closed, 1);
  });

  testWidgets('tts IconButton toggles tts icon via onToggleTts',
      (tester) async {
    var toggled = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          ttsEnabled: true,
          onToggleTts: () => toggled++,
          onClose: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(toggled, 1);
  });

  testWidgets('renders volume_off icon when ttsEnabled is false',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          ttsEnabled: false,
          onToggleTts: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsNothing);
  });

  testWidgets('shows loading fallback when navState is loading',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtaSheet(
          navState: const AsyncValue.loading(),
          ttsEnabled: true,
          onToggleTts: () {},
          onClose: () {},
        ),
      ),
    ));
    expect(find.text('Loading...'), findsOneWidget);
  });
}
