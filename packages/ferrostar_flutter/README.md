# ferrostar_flutter

Flutter bindings for the [Ferrostar](https://github.com/stadiamaps/ferrostar) turn-by-turn navigation SDK.

**Status:** v0.1 — minimal wrapper built for internal use by the [BeeBeeBike](https://github.com/cafca/beebeebike) mobile app. Not on pub.dev.

## Scope

Wraps Ferrostar's native iOS (Swift) and Android (Kotlin) SDKs via method and event channels. Exposes a minimal Dart API covering: controller creation from OSRM JSON, location updates, state stream, spoken instructions stream, route deviation stream, and route replacement for rerouting.

See [the BeeBeeBike design spec](../../docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md) for context.

## Usage

```dart
import 'dart:convert';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';

final osrmJson = jsonDecode(await rootBundle.loadString('route.json'))
    as Map<String, dynamic>;

final controller = await FerrostarFlutter.instance.createController(
  osrmJson: osrmJson,
  waypoints: [
    WaypointInput(lat: origin.lat, lng: origin.lng),
    WaypointInput(lat: dest.lat, lng: dest.lng),
  ],
);

controller.stateStream.listen((state) {
  // state.status, state.currentVisual, state.progress, etc.
});

controller.spokenInstructionStream.listen((s) => tts.speak(s.text));

controller.deviationStream.listen((d) async {
  final newOsrm = await api.requestReroute(currentGps, destination);
  await controller.replaceRoute(newOsrm);
});

// On each GPS fix:
await controller.updateLocation(userLocation);

// On navigation end:
await controller.dispose();
```

See [`example/lib/main.dart`](example/lib/main.dart) for a runnable demo.

## Platform requirements

- iOS 16+
- Android API 25+
- Flutter 3.41+, Dart 3.11+
- iOS uses Flutter's Swift Package Manager plugin integration; CocoaPods is intentionally unsupported.

## Development

After changing any `freezed` or `json_serializable` annotated file:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## License

BSD-3-Clause (matches upstream Ferrostar).
