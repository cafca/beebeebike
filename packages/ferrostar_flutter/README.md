# ferrostar_flutter

Flutter bindings for the [Ferrostar](https://github.com/stadiamaps/ferrostar) turn-by-turn navigation SDK.

**Status:** v0.1 — minimal wrapper built for internal use by the [BeeBeeBike](https://github.com/cafca/beebeebike) mobile app. Not on pub.dev.

## Scope

Wraps Ferrostar's native iOS (Swift) and Android (Kotlin) SDKs via method and event channels. Exposes a minimal Dart API covering: controller creation from OSRM JSON, location updates, state stream, spoken instructions stream, route deviation stream, and route replacement for rerouting.

See [the BeeBeeBike design spec](../../docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md) for context.

## Usage

See `example/lib/main.dart`.

## Platform requirements

- iOS 16+
- Android API 25+
- Flutter 3.19+, Dart 3.3+

## License

BSD-3-Clause (matches upstream Ferrostar).
