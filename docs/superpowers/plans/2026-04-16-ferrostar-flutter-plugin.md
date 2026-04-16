# ferrostar_flutter Plugin v0.1 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a minimal, standalone Flutter plugin that wraps [Ferrostar](https://github.com/stadiamaps/ferrostar)'s native iOS (Swift) and Android (Kotlin) SDKs so that a Dart/Flutter app can drive turn-by-turn navigation without any Dart bindings existing upstream.

**Architecture:** Flutter plugin at `packages/ferrostar_flutter/`. iOS integration uses SPM to pull Ferrostar Swift SDK; Android uses Maven Central. A `MethodChannel` carries imperative calls Dart→Native (create controller, feed location, replace route, dispose); three `EventChannel`s carry state streams Native→Dart (navigation state, spoken instructions, route deviations). Opaque handles keep the heavy `Route` and `TripState` objects on the native side — only UI-relevant derived data crosses the channel boundary.

**Tech Stack:** Flutter 3.19+, Dart 3.3+, Swift 5.9+ (iOS 16+), Kotlin 1.9+ (Android API 25+), FerrostarCore ≥ 0.49.0, freezed, plugin_platform_interface, json_annotation.

**Parent spec:** `docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md`

**Scope (v0.1) — explicit in/out:**

**In:**
- Create a controller from Mapbox Directions v5 / OSRM-compatible JSON
- Push GPS locations in; receive derived navigation state out
- Subscribe to spoken instruction events
- Subscribe to route deviation events
- Replace the active route (for rerouting)
- Dispose

**Out (intentional for v0.1):**
- `NavigationRecorder`, `NavigationCache`, `AlternativeRouteProcessor`
- `SimulatedLocationProvider` (app drives locations from Dart)
- Custom `RouteRequestGenerator` / `RouteResponseParser`
- Background navigation / foreground service
- Publishing to pub.dev
- CarPlay / Android Auto

---

## File Structure

```
packages/ferrostar_flutter/
├── lib/
│   ├── ferrostar_flutter.dart             # Public barrel export
│   └── src/
│       ├── controller.dart                # FerrostarController (public Dart API)
│       ├── ferrostar_flutter.dart         # FerrostarFlutter top-level facade
│       ├── ferrostar_flutter_platform.dart  # plugin_platform_interface
│       ├── method_channel_platform.dart     # MethodChannel impl of platform interface
│       ├── models/
│       │   ├── navigation_state.dart     # freezed
│       │   ├── user_location.dart        # freezed
│       │   ├── trip_progress.dart        # freezed
│       │   ├── visual_instruction.dart   # freezed
│       │   ├── spoken_instruction.dart   # freezed
│       │   ├── route_deviation.dart      # freezed
│       │   ├── waypoint_input.dart       # freezed
│       │   └── navigation_config.dart    # freezed
│       └── exceptions.dart                # FerrostarException etc.
├── test/
│   ├── method_channel_platform_test.dart
│   ├── controller_test.dart
│   └── models/
│       └── navigation_state_test.dart     # round-trip JSON tests
├── ios/
│   ├── ferrostar_flutter.podspec
│   └── Classes/
│       ├── FerrostarFlutterPlugin.swift   # FlutterPlugin entry
│       ├── ControllerRegistry.swift       # Handle-id → NavigationController map
│       ├── ControllerBridge.swift         # Imperative calls from Dart
│       ├── StreamEmitters.swift           # EventChannel handlers
│       ├── Serialization.swift            # Dictionary <-> Ferrostar types
│       └── Errors.swift
├── android/
│   ├── build.gradle
│   ├── settings.gradle
│   └── src/main/kotlin/land/_001/ferrostar_flutter/
│       ├── FerrostarFlutterPlugin.kt
│       ├── ControllerRegistry.kt
│       ├── ControllerBridge.kt
│       ├── StreamEmitters.kt
│       ├── Serialization.kt
│       └── Errors.kt
├── example/                                # Flutter example app
│   ├── lib/main.dart
│   ├── ios/
│   ├── android/
│   └── assets/
│       └── sample_osrm_route.json          # Fixture for driving the example
├── CHANGELOG.md
├── README.md
├── LICENSE                                  # BSD-3 matching Ferrostar
├── analysis_options.yaml
└── pubspec.yaml
```

---

## Method Channel Contract (authoritative reference)

Both iOS and Android implementations conform to this contract. All methods use `MethodChannel` named `land._001/ferrostar_flutter`. All event streams use separate `EventChannel`s named `land._001/ferrostar_flutter/state/<controller_id>`, `.../spoken/<controller_id>`, `.../deviation/<controller_id>`.

**Methods (Dart → Native):**

| Method | Arguments | Returns | Purpose |
|---|---|---|---|
| `createController` | `{osrm_json: Map, waypoints: List<Map>, config: Map}` | `String` (controller_id UUID) | Parse OSRM JSON, instantiate `NavigationController`, register it under a new id |
| `updateLocation` | `{controller_id: String, location: Map}` | `null` | Push a `UserLocation`; state change arrives via state EventChannel |
| `replaceRoute` | `{controller_id: String, osrm_json: Map}` | `null` | Replace the active route without recreating the controller |
| `dispose` | `{controller_id: String}` | `null` | Release native resources, close streams |

**State event payloads (Native → Dart, via state EventChannel):**

```jsonc
// NavigationState JSON schema
{
  "status": "idle" | "navigating" | "complete",
  "is_off_route": true | false,
  "snapped_location": {            // nullable; present while navigating
    "lat": 52.52, "lng": 13.405,
    "horizontal_accuracy_m": 5.0,
    "course_deg": 42.0,            // nullable
    "speed_mps": 4.3,              // nullable
    "timestamp_ms": 1744800000000
  },
  "progress": {                    // nullable
    "distance_to_next_maneuver_m": 210.0,
    "distance_remaining_m": 2800.0,
    "duration_remaining_ms": 620000
  },
  "current_visual": {              // nullable
    "primary_text": "Turn left onto Kastanienallee",
    "secondary_text": null,
    "maneuver_type": "turn",       // string from Ferrostar ManeuverType
    "maneuver_modifier": "left",   // nullable
    "trigger_distance_m": 200.0
  },
  "current_step": {                // nullable
    "index": 3,
    "road_name": "Kastanienallee"
  }
}
```

**Spoken instruction payload:**

```jsonc
{
  "uuid": "a3f1...",
  "text": "In 200 meters, turn left onto Kastanienallee",
  "ssml": null,
  "trigger_distance_m": 200.0,
  "emitted_at_ms": 1744800000000
}
```

**Route deviation payload:**

```jsonc
{
  "deviation_m": 87.0,
  "duration_off_route_ms": 12000,
  "user_location": { ...UserLocation }
}
```

**Error model:** Native code throws `FlutterError` with `code` ∈ `{"invalid_argument", "route_parse_failed", "unknown_controller", "ferrostar_error", "internal"}` and a `message` string. Dart side maps these to `FerrostarException` subclasses.

---

## Phase 1: Project Scaffold

### Task 1: Create worktree / branch for plugin work

**Files:** none (workspace operation)

- [ ] **Step 1: Create a dedicated worktree**

The plugin is its own artifact; work on a dedicated branch so it can be reviewed/merged independently.

```bash
cd /Users/pv/code/ortschaft
git worktree add .claude/worktrees/ferrostar-plugin -b feature/ferrostar-flutter-plugin origin/main
cd .claude/worktrees/ferrostar-plugin
```

- [ ] **Step 2: Verify worktree**

```bash
git rev-parse --abbrev-ref HEAD
# Expected: feature/ferrostar-flutter-plugin
```

---

### Task 2: Scaffold the Flutter plugin package

**Files:**
- Create: `packages/ferrostar_flutter/` (generated by `flutter create`)

- [ ] **Step 1: Verify Flutter version**

```bash
flutter --version
```
Expected: Flutter 3.19.0 or higher, Dart 3.3 or higher. If not, install via `fvm` or direct.

- [ ] **Step 2: Create the plugin scaffold**

```bash
mkdir -p packages
flutter create \
  --template=plugin \
  --platforms=ios,android \
  --org=land._001 \
  --project-name=ferrostar_flutter \
  packages/ferrostar_flutter
```

- [ ] **Step 3: Verify scaffold compiles**

```bash
cd packages/ferrostar_flutter
flutter pub get
cd example
flutter pub get
flutter build ios --no-codesign --simulator
```
Expected: builds cleanly.

- [ ] **Step 4: Commit the scaffold**

```bash
cd /Users/pv/code/ortschaft/.claude/worktrees/ferrostar-plugin
git add packages/ferrostar_flutter
git commit -m "chore(plugin): scaffold ferrostar_flutter with flutter create"
```

---

### Task 3: Configure plugin metadata

**Files:**
- Modify: `packages/ferrostar_flutter/pubspec.yaml`
- Create: `packages/ferrostar_flutter/README.md`
- Create: `packages/ferrostar_flutter/CHANGELOG.md`
- Create: `packages/ferrostar_flutter/LICENSE`
- Modify: `packages/ferrostar_flutter/analysis_options.yaml`

- [ ] **Step 1: Update pubspec with real metadata and dependencies**

Replace the generated `pubspec.yaml` with:

```yaml
name: ferrostar_flutter
description: Flutter bindings for the Ferrostar turn-by-turn navigation SDK. Minimal v0.1 wrapping Swift (iOS) and Kotlin (Android) core libraries.
version: 0.1.0
homepage: https://github.com/cafca/beebeebike/tree/main/packages/ferrostar_flutter
repository: https://github.com/cafca/beebeebike

environment:
  sdk: ^3.3.0
  flutter: ^3.19.0

dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.1.8
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  build_runner: ^2.4.11
  freezed: ^2.5.7
  json_serializable: ^6.8.0

flutter:
  plugin:
    platforms:
      ios:
        pluginClass: FerrostarFlutterPlugin
      android:
        package: land._001.ferrostar_flutter
        pluginClass: FerrostarFlutterPlugin
```

- [ ] **Step 2: Write README**

```markdown
# ferrostar_flutter

Flutter bindings for the [Ferrostar](https://github.com/stadiamaps/ferrostar) turn-by-turn navigation SDK.

**Status:** v0.1 — minimal wrapper built for internal use by the [Ortschaft](https://github.com/cafca/beebeebike) mobile app. Not on pub.dev.

## Scope

Wraps Ferrostar's native iOS (Swift) and Android (Kotlin) SDKs via method and event channels. Exposes a minimal Dart API covering: controller creation from OSRM JSON, location updates, state stream, spoken instructions stream, route deviation stream, and route replacement for rerouting.

See [the Ortschaft design spec](../../docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md) for context.

## Usage

See `example/lib/main.dart`.

## Platform requirements

- iOS 16+
- Android API 25+
- Flutter 3.19+, Dart 3.3+

## License

BSD-3-Clause (matches upstream Ferrostar).
```

- [ ] **Step 3: Write CHANGELOG**

```markdown
# Changelog

## 0.1.0 (unreleased)

Initial release. Minimal wrapper around Ferrostar iOS/Android SDKs.
```

- [ ] **Step 4: Copy LICENSE**

```bash
curl -sSL https://raw.githubusercontent.com/stadiamaps/ferrostar/main/LICENSE -o packages/ferrostar_flutter/LICENSE
```

- [ ] **Step 5: Strengthen lints**

Replace `analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    missing_required_param: error
    missing_return: error
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_declare_return_types
    - avoid_dynamic_calls
    - avoid_print
    - prefer_const_constructors
    - prefer_final_locals
```

- [ ] **Step 6: Verify pub get succeeds**

```bash
cd packages/ferrostar_flutter
flutter pub get
```
Expected: success, no warnings.

- [ ] **Step 7: Commit**

```bash
git add packages/ferrostar_flutter/pubspec.yaml \
  packages/ferrostar_flutter/README.md \
  packages/ferrostar_flutter/CHANGELOG.md \
  packages/ferrostar_flutter/LICENSE \
  packages/ferrostar_flutter/analysis_options.yaml
git commit -m "chore(plugin): configure pubspec, README, license, lints"
```

---

## Phase 2: Integrate Ferrostar Native SDKs (proof-of-life)

Goal: confirm FerrostarCore links and builds on both platforms. Do this BEFORE writing Dart code — if linking fails, we need to know early.

### Task 4: Wire Ferrostar Swift SDK on iOS (proof-of-life)

**Files:**
- Modify: `packages/ferrostar_flutter/ios/ferrostar_flutter.podspec`
- Modify: `packages/ferrostar_flutter/ios/Classes/FerrostarFlutterPlugin.swift`
- Modify: `packages/ferrostar_flutter/example/ios/Podfile`

- [ ] **Step 1: Declare FerrostarCore as a dependency in the podspec**

Ferrostar publishes a CocoaPods spec via the `ferrostar_ios` repo. Update the podspec:

```ruby
Pod::Spec.new do |s|
  s.name             = 'ferrostar_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter bindings for Ferrostar navigation SDK.'
  s.description      = 'See README.'
  s.homepage         = 'https://github.com/cafca/beebeebike'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Vincent Ahrend' => 'cafca@001.land' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'FerrostarCore', '~> 0.49'
  s.platform         = :ios, '16.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.9'
end
```

- [ ] **Step 2: Verify Ferrostar is on CocoaPods**

```bash
pod search FerrostarCore
```

Expected: shows FerrostarCore with version 0.49.x. **If the pod is not listed (Ferrostar publishes primarily via SPM), fall through to Step 2a.**

- [ ] **Step 2a (conditional): Use SPM integration instead**

If FerrostarCore is not on CocoaPods, update the podspec to declare the SPM package as a pod dependency via `s.dependency` is not possible for SPM. Instead:

1. Remove the `s.dependency 'FerrostarCore'` line
2. In `packages/ferrostar_flutter/example/ios/Podfile`, add SPM integration via Xcode project manipulation — open `example/ios/Runner.xcworkspace` in Xcode, add Ferrostar via File → Add Package Dependencies, URL `https://github.com/stadiamaps/ferrostar`, version "Up to Next Major Version: 0.49.0"
3. Verify that modules `FerrostarCore`, `FerrostarCoreFFI` are importable

Document which path was used in `packages/ferrostar_flutter/ios/INTEGRATION.md`:

```markdown
# iOS Integration

FerrostarCore is integrated via [CocoaPods|Swift Package Manager].

[Notes about which path was taken and why.]
```

- [ ] **Step 3: Add a smoke-test import in FerrostarFlutterPlugin.swift**

Replace the generated `FerrostarFlutterPlugin.swift` with a minimal smoke test:

```swift
import Flutter
import UIKit
import FerrostarCore
import FerrostarCoreFFI

public class FerrostarFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "land._001/ferrostar_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = FerrostarFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "smokeTest":
      // Import-only smoke test: prove FerrostarCore types are reachable.
      let sampleLocation = UserLocation(
        coordinates: GeographicCoordinate(lat: 52.52, lng: 13.405),
        horizontalAccuracy: 5.0,
        courseOverGround: nil,
        timestamp: Date(),
        speed: nil
      )
      result("location created at \(sampleLocation.coordinates.lat), \(sampleLocation.coordinates.lng)")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```

- [ ] **Step 4: Set iOS platform target in example Podfile**

Edit `packages/ferrostar_flutter/example/ios/Podfile`:

```ruby
platform :ios, '16.0'
```

- [ ] **Step 5: Build the example app for iOS simulator**

```bash
cd packages/ferrostar_flutter/example
flutter build ios --no-codesign --simulator
```
Expected: builds without errors. Link errors here indicate incorrect FerrostarCore integration — fix before proceeding.

- [ ] **Step 6: Run the smoke test**

Add a tiny button in `example/lib/main.dart` that invokes `smokeTest`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: SmokeHome()));

class SmokeHome extends StatefulWidget {
  const SmokeHome({super.key});
  @override
  State<SmokeHome> createState() => _SmokeHomeState();
}

class _SmokeHomeState extends State<SmokeHome> {
  static const _ch = MethodChannel('land._001/ferrostar_flutter');
  String _out = '(tap)';

  Future<void> _run() async {
    final res = await _ch.invokeMethod<String>('smokeTest');
    setState(() => _out = res ?? 'null');
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_out),
            ElevatedButton(onPressed: _run, child: const Text('Smoke test')),
          ]),
        ),
      );
}
```

Run the example on the iOS simulator. Tap "Smoke test". Expected output: `location created at 52.52, 13.405`.

- [ ] **Step 7: Commit the proof-of-life**

```bash
git add packages/ferrostar_flutter/ios \
  packages/ferrostar_flutter/example/ios/Podfile \
  packages/ferrostar_flutter/example/lib/main.dart
git commit -m "feat(plugin,ios): link FerrostarCore, verify import with smoke test"
```

---

### Task 5: Wire Ferrostar Kotlin SDK on Android (proof-of-life)

**Files:**
- Modify: `packages/ferrostar_flutter/android/build.gradle`
- Modify: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/FerrostarFlutterPlugin.kt`
- Modify: `packages/ferrostar_flutter/example/android/app/build.gradle`

- [ ] **Step 1: Add Ferrostar Kotlin dependency**

Edit `packages/ferrostar_flutter/android/build.gradle` — replace the dependencies block:

```gradle
dependencies {
    implementation 'com.stadiamaps.ferrostar:core:0.49.0'
}
```

Ensure `minSdkVersion` is 25 (or higher):

```gradle
android {
    defaultConfig {
        minSdkVersion 25
    }
}
```

- [ ] **Step 2: Set minSdk on example app**

Edit `packages/ferrostar_flutter/example/android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdk 25
    }
}
```

- [ ] **Step 3: Update plugin entry point with smoke test**

Replace `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/FerrostarFlutterPlugin.kt`:

```kotlin
package land._001.ferrostar_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.stadiamaps.ferrostar.core.GeographicCoordinate
import com.stadiamaps.ferrostar.core.UserLocation
import java.time.Instant

class FerrostarFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "land._001/ferrostar_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "smokeTest" -> {
                val loc = UserLocation(
                    coordinates = GeographicCoordinate(lat = 52.52, lng = 13.405),
                    horizontalAccuracy = 5.0,
                    courseOverGround = null,
                    timestamp = Instant.now(),
                    speed = null,
                )
                result.success("location created at ${loc.coordinates.lat}, ${loc.coordinates.lng}")
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
```

- [ ] **Step 4: Build the example for Android**

```bash
cd packages/ferrostar_flutter/example
flutter build apk --debug
```
Expected: builds successfully. Dependency resolution or NDK errors need to be fixed now.

- [ ] **Step 5: Run smoke test on Android emulator**

Launch emulator, run `flutter run -d emulator`. Tap the Smoke button.
Expected: same output `location created at 52.52, 13.405`.

- [ ] **Step 6: Commit**

```bash
git add packages/ferrostar_flutter/android \
  packages/ferrostar_flutter/example/android
git commit -m "feat(plugin,android): link Ferrostar Kotlin SDK, verify import with smoke test"
```

**Decision gate:** if either platform smoke test fails, stop here and resolve the integration issue. Do not proceed with Dart API work over a broken native layer.

---

## Phase 3: Dart Data Models

All models use `freezed` + `json_serializable`. TDD: write a round-trip JSON test first for each model; implement to make it pass.

### Task 6: Set up build_runner pipeline

**Files:**
- Modify: `packages/ferrostar_flutter/pubspec.yaml` (already done in Task 3)

- [ ] **Step 1: Generate initial (empty) code**

```bash
cd packages/ferrostar_flutter
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0. (Nothing to generate yet, just verifies the toolchain.)

- [ ] **Step 2: Add build_runner run to README's developer section**

Append to `packages/ferrostar_flutter/README.md`:

```markdown
## Development

After changing any `freezed` or `json_serializable` annotated file:

```bash
dart run build_runner build --delete-conflicting-outputs
```
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/README.md
git commit -m "docs(plugin): note build_runner command for codegen"
```

---

### Task 7: `UserLocation` model + round-trip test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/user_location.dart`
- Create: `packages/ferrostar_flutter/test/models/user_location_test.dart`

- [ ] **Step 1: Write the failing test**

`packages/ferrostar_flutter/test/models/user_location_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';

void main() {
  group('UserLocation', () {
    test('round-trips through JSON', () {
      final json = {
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'course_deg': 42.0,
        'speed_mps': 4.3,
        'timestamp_ms': 1744800000000,
      };

      final loc = UserLocation.fromJson(json);
      expect(loc.lat, 52.52);
      expect(loc.lng, 13.405);
      expect(loc.horizontalAccuracyM, 5.0);
      expect(loc.courseDeg, 42.0);
      expect(loc.speedMps, 4.3);
      expect(loc.timestampMs, 1744800000000);

      expect(loc.toJson(), json);
    });

    test('parses with nullable course and speed absent', () {
      final loc = UserLocation.fromJson({
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'timestamp_ms': 1744800000000,
      });
      expect(loc.courseDeg, isNull);
      expect(loc.speedMps, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test (expect fail)**

```bash
cd packages/ferrostar_flutter
flutter test test/models/user_location_test.dart
```
Expected: error `Target of URI doesn't exist` — the model file doesn't exist.

- [ ] **Step 3: Implement the model**

`packages/ferrostar_flutter/lib/src/models/user_location.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_location.freezed.dart';
part 'user_location.g.dart';

@freezed
class UserLocation with _$UserLocation {
  const factory UserLocation({
    required double lat,
    required double lng,
    @JsonKey(name: 'horizontal_accuracy_m') required double horizontalAccuracyM,
    @JsonKey(name: 'course_deg') double? courseDeg,
    @JsonKey(name: 'speed_mps') double? speedMps,
    @JsonKey(name: 'timestamp_ms') required int timestampMs,
  }) = _UserLocation;

  factory UserLocation.fromJson(Map<String, dynamic> json) =>
      _$UserLocationFromJson(json);
}
```

- [ ] **Step 4: Generate and re-run test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/user_location_test.dart
```
Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/user_location.dart \
  packages/ferrostar_flutter/lib/src/models/user_location.freezed.dart \
  packages/ferrostar_flutter/lib/src/models/user_location.g.dart \
  packages/ferrostar_flutter/test/models/user_location_test.dart
git commit -m "feat(plugin): add UserLocation model"
```

---

### Task 8: `TripProgress` model + test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/trip_progress.dart`
- Create: `packages/ferrostar_flutter/test/models/trip_progress_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/models/trip_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/trip_progress.dart';

void main() {
  test('TripProgress round-trips', () {
    final json = {
      'distance_to_next_maneuver_m': 210.0,
      'distance_remaining_m': 2800.0,
      'duration_remaining_ms': 620000,
    };
    final p = TripProgress.fromJson(json);
    expect(p.distanceToNextManeuverM, 210.0);
    expect(p.distanceRemainingM, 2800.0);
    expect(p.durationRemainingMs, 620000);
    expect(p.toJson(), json);
  });
}
```

- [ ] **Step 2: Run (expect fail)**

```bash
flutter test test/models/trip_progress_test.dart
```

- [ ] **Step 3: Implement**

```dart
// lib/src/models/trip_progress.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'trip_progress.freezed.dart';
part 'trip_progress.g.dart';

@freezed
class TripProgress with _$TripProgress {
  const factory TripProgress({
    @JsonKey(name: 'distance_to_next_maneuver_m') required double distanceToNextManeuverM,
    @JsonKey(name: 'distance_remaining_m') required double distanceRemainingM,
    @JsonKey(name: 'duration_remaining_ms') required int durationRemainingMs,
  }) = _TripProgress;

  factory TripProgress.fromJson(Map<String, dynamic> json) =>
      _$TripProgressFromJson(json);
}
```

- [ ] **Step 4: Generate and run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/trip_progress_test.dart
```
Expected: pass.

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/trip_progress.dart \
  packages/ferrostar_flutter/lib/src/models/trip_progress.freezed.dart \
  packages/ferrostar_flutter/lib/src/models/trip_progress.g.dart \
  packages/ferrostar_flutter/test/models/trip_progress_test.dart
git commit -m "feat(plugin): add TripProgress model"
```

---

### Task 9: `VisualInstruction` model + test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/visual_instruction.dart`
- Create: `packages/ferrostar_flutter/test/models/visual_instruction_test.dart`

- [ ] **Step 1: Test**

```dart
// test/models/visual_instruction_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/visual_instruction.dart';

void main() {
  test('VisualInstruction with all fields round-trips', () {
    final json = {
      'primary_text': 'Turn left onto Kastanienallee',
      'secondary_text': 'then continue for 1.2 km',
      'maneuver_type': 'turn',
      'maneuver_modifier': 'left',
      'trigger_distance_m': 200.0,
    };
    final v = VisualInstruction.fromJson(json);
    expect(v.primaryText, 'Turn left onto Kastanienallee');
    expect(v.secondaryText, 'then continue for 1.2 km');
    expect(v.maneuverType, 'turn');
    expect(v.maneuverModifier, 'left');
    expect(v.triggerDistanceM, 200.0);
    expect(v.toJson(), json);
  });

  test('VisualInstruction with null modifier + secondary parses', () {
    final v = VisualInstruction.fromJson({
      'primary_text': 'Continue straight',
      'secondary_text': null,
      'maneuver_type': 'continue',
      'maneuver_modifier': null,
      'trigger_distance_m': 500.0,
    });
    expect(v.secondaryText, isNull);
    expect(v.maneuverModifier, isNull);
  });
}
```

- [ ] **Step 2: Run (expect fail), implement, regenerate, pass**

Implementation:

```dart
// lib/src/models/visual_instruction.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'visual_instruction.freezed.dart';
part 'visual_instruction.g.dart';

@freezed
class VisualInstruction with _$VisualInstruction {
  const factory VisualInstruction({
    @JsonKey(name: 'primary_text') required String primaryText,
    @JsonKey(name: 'secondary_text') String? secondaryText,
    @JsonKey(name: 'maneuver_type') required String maneuverType,
    @JsonKey(name: 'maneuver_modifier') String? maneuverModifier,
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,
  }) = _VisualInstruction;

  factory VisualInstruction.fromJson(Map<String, dynamic> json) =>
      _$VisualInstructionFromJson(json);
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/visual_instruction_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/visual_instruction.* \
  packages/ferrostar_flutter/test/models/visual_instruction_test.dart
git commit -m "feat(plugin): add VisualInstruction model"
```

---

### Task 10: `SpokenInstruction` model + test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/spoken_instruction.dart`
- Create: `packages/ferrostar_flutter/test/models/spoken_instruction_test.dart`

- [ ] **Step 1: Test**

```dart
// test/models/spoken_instruction_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/spoken_instruction.dart';

void main() {
  test('SpokenInstruction round-trips with ssml', () {
    final json = {
      'uuid': 'a3f1',
      'text': 'In 200 meters, turn left onto Kastanienallee',
      'ssml': '<speak>In 200 meters, turn left</speak>',
      'trigger_distance_m': 200.0,
      'emitted_at_ms': 1744800000000,
    };
    final s = SpokenInstruction.fromJson(json);
    expect(s.uuid, 'a3f1');
    expect(s.text, startsWith('In 200'));
    expect(s.ssml, isNotNull);
    expect(s.toJson(), json);
  });

  test('SpokenInstruction round-trips with null ssml', () {
    final s = SpokenInstruction.fromJson({
      'uuid': 'a3f1',
      'text': 'Continue',
      'ssml': null,
      'trigger_distance_m': 500.0,
      'emitted_at_ms': 1,
    });
    expect(s.ssml, isNull);
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/src/models/spoken_instruction.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'spoken_instruction.freezed.dart';
part 'spoken_instruction.g.dart';

@freezed
class SpokenInstruction with _$SpokenInstruction {
  const factory SpokenInstruction({
    required String uuid,
    required String text,
    String? ssml,
    @JsonKey(name: 'trigger_distance_m') required double triggerDistanceM,
    @JsonKey(name: 'emitted_at_ms') required int emittedAtMs,
  }) = _SpokenInstruction;

  factory SpokenInstruction.fromJson(Map<String, dynamic> json) =>
      _$SpokenInstructionFromJson(json);
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/spoken_instruction_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/spoken_instruction.* \
  packages/ferrostar_flutter/test/models/spoken_instruction_test.dart
git commit -m "feat(plugin): add SpokenInstruction model"
```

---

### Task 11: `RouteDeviation` model + test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/route_deviation.dart`
- Create: `packages/ferrostar_flutter/test/models/route_deviation_test.dart`

- [ ] **Step 1: Test**

```dart
// test/models/route_deviation_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/route_deviation.dart';

void main() {
  test('RouteDeviation round-trips', () {
    final json = {
      'deviation_m': 87.0,
      'duration_off_route_ms': 12000,
      'user_location': {
        'lat': 52.52,
        'lng': 13.405,
        'horizontal_accuracy_m': 5.0,
        'timestamp_ms': 1744800000000,
      },
    };
    final d = RouteDeviation.fromJson(json);
    expect(d.deviationM, 87.0);
    expect(d.durationOffRouteMs, 12000);
    expect(d.userLocation.lat, 52.52);
    expect(d.toJson(), json);
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/src/models/route_deviation.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_location.dart';

part 'route_deviation.freezed.dart';
part 'route_deviation.g.dart';

@freezed
class RouteDeviation with _$RouteDeviation {
  const factory RouteDeviation({
    @JsonKey(name: 'deviation_m') required double deviationM,
    @JsonKey(name: 'duration_off_route_ms') required int durationOffRouteMs,
    @JsonKey(name: 'user_location') required UserLocation userLocation,
  }) = _RouteDeviation;

  factory RouteDeviation.fromJson(Map<String, dynamic> json) =>
      _$RouteDeviationFromJson(json);
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/route_deviation_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/route_deviation.* \
  packages/ferrostar_flutter/test/models/route_deviation_test.dart
git commit -m "feat(plugin): add RouteDeviation model"
```

---

### Task 12: `NavigationState`, `StepRef`, `TripStatus` models + test

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/navigation_state.dart`
- Create: `packages/ferrostar_flutter/test/models/navigation_state_test.dart`

- [ ] **Step 1: Test**

```dart
// test/models/navigation_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/navigation_state.dart';

void main() {
  group('NavigationState', () {
    test('idle state parses with all nullable fields null', () {
      final json = {
        'status': 'idle',
        'is_off_route': false,
        'snapped_location': null,
        'progress': null,
        'current_visual': null,
        'current_step': null,
      };
      final s = NavigationState.fromJson(json);
      expect(s.status, TripStatus.idle);
      expect(s.isOffRoute, false);
      expect(s.snappedLocation, isNull);
      expect(s.progress, isNull);
      expect(s.currentVisual, isNull);
      expect(s.currentStep, isNull);
      expect(s.toJson(), json);
    });

    test('navigating state parses with all fields populated', () {
      final json = {
        'status': 'navigating',
        'is_off_route': false,
        'snapped_location': {
          'lat': 52.52,
          'lng': 13.405,
          'horizontal_accuracy_m': 5.0,
          'course_deg': 42.0,
          'speed_mps': 4.3,
          'timestamp_ms': 1744800000000,
        },
        'progress': {
          'distance_to_next_maneuver_m': 210.0,
          'distance_remaining_m': 2800.0,
          'duration_remaining_ms': 620000,
        },
        'current_visual': {
          'primary_text': 'Turn left',
          'secondary_text': null,
          'maneuver_type': 'turn',
          'maneuver_modifier': 'left',
          'trigger_distance_m': 200.0,
        },
        'current_step': {
          'index': 3,
          'road_name': 'Kastanienallee',
        },
      };
      final s = NavigationState.fromJson(json);
      expect(s.status, TripStatus.navigating);
      expect(s.snappedLocation!.lat, 52.52);
      expect(s.progress!.distanceRemainingM, 2800.0);
      expect(s.currentVisual!.primaryText, 'Turn left');
      expect(s.currentStep!.index, 3);
      expect(s.currentStep!.roadName, 'Kastanienallee');
    });

    test('complete status parses', () {
      final s = NavigationState.fromJson({
        'status': 'complete',
        'is_off_route': false,
        'snapped_location': null,
        'progress': null,
        'current_visual': null,
        'current_step': null,
      });
      expect(s.status, TripStatus.complete);
    });

    test('unknown status throws', () {
      expect(
        () => NavigationState.fromJson({
          'status': 'banana',
          'is_off_route': false,
          'snapped_location': null,
          'progress': null,
          'current_visual': null,
          'current_step': null,
        }),
        throwsA(isA<CheckedFromJsonException>()),
      );
    });
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/src/models/navigation_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'user_location.dart';
import 'trip_progress.dart';
import 'visual_instruction.dart';

part 'navigation_state.freezed.dart';
part 'navigation_state.g.dart';

enum TripStatus {
  @JsonValue('idle') idle,
  @JsonValue('navigating') navigating,
  @JsonValue('complete') complete,
}

@freezed
class StepRef with _$StepRef {
  const factory StepRef({
    required int index,
    @JsonKey(name: 'road_name') required String roadName,
  }) = _StepRef;

  factory StepRef.fromJson(Map<String, dynamic> json) =>
      _$StepRefFromJson(json);
}

@freezed
class NavigationState with _$NavigationState {
  const factory NavigationState({
    required TripStatus status,
    @JsonKey(name: 'is_off_route') required bool isOffRoute,
    @JsonKey(name: 'snapped_location') UserLocation? snappedLocation,
    TripProgress? progress,
    @JsonKey(name: 'current_visual') VisualInstruction? currentVisual,
    @JsonKey(name: 'current_step') StepRef? currentStep,
  }) = _NavigationState;

  factory NavigationState.fromJson(Map<String, dynamic> json) =>
      _$NavigationStateFromJson(json);
}
```

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/navigation_state_test.dart
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/navigation_state.* \
  packages/ferrostar_flutter/test/models/navigation_state_test.dart
git commit -m "feat(plugin): add NavigationState + StepRef + TripStatus"
```

---

### Task 13: `WaypointInput` and `NavigationConfig` models

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/models/waypoint_input.dart`
- Create: `packages/ferrostar_flutter/lib/src/models/navigation_config.dart`
- Create: `packages/ferrostar_flutter/test/models/inputs_test.dart`

- [ ] **Step 1: Test**

```dart
// test/models/inputs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';

void main() {
  test('WaypointInput serializes', () {
    final w = const WaypointInput(lat: 52.52, lng: 13.405, kind: WaypointKind.viaPoint);
    expect(w.toJson(), {'lat': 52.52, 'lng': 13.405, 'kind': 'via_point'});
  });

  test('WaypointInput kinds', () {
    expect(WaypointInput.fromJson({'lat': 0.0, 'lng': 0.0, 'kind': 'break'}).kind,
        WaypointKind.breakPoint);
  });

  test('NavigationConfig default serializes with sane defaults', () {
    const c = NavigationConfig();
    final j = c.toJson();
    expect(j['deviation_threshold_m'], 50.0);
    expect(j['deviation_duration_threshold_ms'], 10000);
    expect(j['snap_user_location_to_route'], true);
  });
}
```

- [ ] **Step 2: Implement `waypoint_input.dart`**

```dart
// lib/src/models/waypoint_input.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'waypoint_input.freezed.dart';
part 'waypoint_input.g.dart';

enum WaypointKind {
  @JsonValue('break') breakPoint,
  @JsonValue('via_point') viaPoint,
}

@freezed
class WaypointInput with _$WaypointInput {
  const factory WaypointInput({
    required double lat,
    required double lng,
    @Default(WaypointKind.breakPoint) WaypointKind kind,
  }) = _WaypointInput;

  factory WaypointInput.fromJson(Map<String, dynamic> json) =>
      _$WaypointInputFromJson(json);
}
```

- [ ] **Step 3: Implement `navigation_config.dart`**

```dart
// lib/src/models/navigation_config.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'navigation_config.freezed.dart';
part 'navigation_config.g.dart';

@freezed
class NavigationConfig with _$NavigationConfig {
  const factory NavigationConfig({
    @JsonKey(name: 'deviation_threshold_m') @Default(50.0) double deviationThresholdM,
    @JsonKey(name: 'deviation_duration_threshold_ms') @Default(10000) int deviationDurationThresholdMs,
    @JsonKey(name: 'snap_user_location_to_route') @Default(true) bool snapUserLocationToRoute,
  }) = _NavigationConfig;

  factory NavigationConfig.fromJson(Map<String, dynamic> json) =>
      _$NavigationConfigFromJson(json);
}
```

- [ ] **Step 4: Generate, run**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/models/inputs_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/models/waypoint_input.* \
  packages/ferrostar_flutter/lib/src/models/navigation_config.* \
  packages/ferrostar_flutter/test/models/inputs_test.dart
git commit -m "feat(plugin): add WaypointInput and NavigationConfig models"
```

---

## Phase 4: Dart Platform Interface + Public API

### Task 14: Platform interface

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/ferrostar_flutter_platform.dart`

- [ ] **Step 1: Implement**

```dart
// lib/src/ferrostar_flutter_platform.dart
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'models/navigation_config.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';
import 'models/waypoint_input.dart';
import 'method_channel_platform.dart';

abstract class FerrostarFlutterPlatform extends PlatformInterface {
  FerrostarFlutterPlatform() : super(token: _token);
  static final Object _token = Object();

  static FerrostarFlutterPlatform _instance = MethodChannelFerrostarFlutter();
  static FerrostarFlutterPlatform get instance => _instance;
  static set instance(FerrostarFlutterPlatform inst) {
    PlatformInterface.verifyToken(inst, _token);
    _instance = inst;
  }

  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  });

  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  });

  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  });

  Future<void> dispose({required String controllerId});

  Stream<NavigationState> stateStream({required String controllerId});
  Stream<SpokenInstruction> spokenInstructionStream({required String controllerId});
  Stream<RouteDeviation> deviationStream({required String controllerId});
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/ferrostar_flutter_platform.dart
git commit -m "feat(plugin): define FerrostarFlutterPlatform interface"
```

---

### Task 15: MethodChannel platform implementation + unit tests

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/method_channel_platform.dart`
- Create: `packages/ferrostar_flutter/test/method_channel_platform_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// test/method_channel_platform_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/src/method_channel_platform.dart';
import 'package:ferrostar_flutter/src/models/navigation_config.dart';
import 'package:ferrostar_flutter/src/models/user_location.dart';
import 'package:ferrostar_flutter/src/models/waypoint_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelFerrostarFlutter();
  const channel = MethodChannel('land._001/ferrostar_flutter');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      log.add(call);
      switch (call.method) {
        case 'createController': return 'ctrl-1';
        case 'updateLocation': return null;
        case 'replaceRoute': return null;
        case 'dispose': return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('createController sends osrm_json, waypoints, config', () async {
    final id = await platform.createController(
      osrmJson: {'code': 'Ok', 'routes': []},
      waypoints: [
        const WaypointInput(lat: 52.52, lng: 13.405),
        const WaypointInput(lat: 52.50, lng: 13.40),
      ],
      config: const NavigationConfig(),
    );
    expect(id, 'ctrl-1');
    expect(log, hasLength(1));
    expect(log.first.method, 'createController');
    final args = log.first.arguments as Map;
    expect(args['osrm_json'], isA<Map>());
    expect((args['waypoints'] as List), hasLength(2));
    expect(args['config'], isA<Map>());
  });

  test('updateLocation sends controller_id and location map', () async {
    await platform.updateLocation(
      controllerId: 'ctrl-1',
      location: const UserLocation(
        lat: 52.52, lng: 13.405, horizontalAccuracyM: 5.0, timestampMs: 1,
      ),
    );
    expect(log.single.method, 'updateLocation');
    final args = log.single.arguments as Map;
    expect(args['controller_id'], 'ctrl-1');
    expect((args['location'] as Map)['lat'], 52.52);
  });

  test('replaceRoute sends controller_id and osrm_json', () async {
    await platform.replaceRoute(
      controllerId: 'ctrl-1',
      osrmJson: {'code': 'Ok', 'routes': []},
    );
    expect(log.single.method, 'replaceRoute');
  });

  test('dispose sends controller_id', () async {
    await platform.dispose(controllerId: 'ctrl-1');
    expect(log.single.method, 'dispose');
    expect((log.single.arguments as Map)['controller_id'], 'ctrl-1');
  });
}
```

- [ ] **Step 2: Implement**

```dart
// lib/src/method_channel_platform.dart
import 'dart:async';
import 'package:flutter/services.dart';
import 'ferrostar_flutter_platform.dart';
import 'models/navigation_config.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';
import 'models/waypoint_input.dart';

const _channelName = 'land._001/ferrostar_flutter';

class MethodChannelFerrostarFlutter extends FerrostarFlutterPlatform {
  final MethodChannel _channel = const MethodChannel(_channelName);

  @override
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  }) async {
    final result = await _channel.invokeMethod<String>('createController', {
      'osrm_json': osrmJson,
      'waypoints': waypoints.map((w) => w.toJson()).toList(),
      'config': config.toJson(),
    });
    return result!;
  }

  @override
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  }) async {
    await _channel.invokeMethod<void>('updateLocation', {
      'controller_id': controllerId,
      'location': location.toJson(),
    });
  }

  @override
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  }) async {
    await _channel.invokeMethod<void>('replaceRoute', {
      'controller_id': controllerId,
      'osrm_json': osrmJson,
    });
  }

  @override
  Future<void> dispose({required String controllerId}) async {
    await _channel.invokeMethod<void>('dispose', {'controller_id': controllerId});
  }

  @override
  Stream<NavigationState> stateStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/state/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => NavigationState.fromJson(Map<String, dynamic>.from(e as Map)));
  }

  @override
  Stream<SpokenInstruction> spokenInstructionStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/spoken/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => SpokenInstruction.fromJson(Map<String, dynamic>.from(e as Map)));
  }

  @override
  Stream<RouteDeviation> deviationStream({required String controllerId}) {
    final ch = EventChannel('$_channelName/deviation/$controllerId');
    return ch
        .receiveBroadcastStream()
        .map((e) => RouteDeviation.fromJson(Map<String, dynamic>.from(e as Map)));
  }
}
```

- [ ] **Step 3: Run tests**

```bash
flutter test test/method_channel_platform_test.dart
```
Expected: all 4 tests pass.

- [ ] **Step 4: Commit**

```bash
git add packages/ferrostar_flutter/lib/src/method_channel_platform.dart \
  packages/ferrostar_flutter/test/method_channel_platform_test.dart
git commit -m "feat(plugin): MethodChannel platform impl + tests"
```

---

### Task 16: Public Dart API facade (`FerrostarFlutter` + `FerrostarController`)

**Files:**
- Create: `packages/ferrostar_flutter/lib/src/ferrostar_flutter.dart`
- Create: `packages/ferrostar_flutter/lib/src/controller.dart`
- Create: `packages/ferrostar_flutter/lib/src/exceptions.dart`
- Create: `packages/ferrostar_flutter/lib/ferrostar_flutter.dart` (barrel)
- Create: `packages/ferrostar_flutter/test/controller_test.dart`

- [ ] **Step 1: Exceptions**

```dart
// lib/src/exceptions.dart
class FerrostarException implements Exception {
  final String code;
  final String message;
  FerrostarException(this.code, this.message);
  @override
  String toString() => 'FerrostarException($code): $message';
}

class InvalidArgumentException extends FerrostarException {
  InvalidArgumentException(String message) : super('invalid_argument', message);
}

class RouteParseException extends FerrostarException {
  RouteParseException(String message) : super('route_parse_failed', message);
}

class UnknownControllerException extends FerrostarException {
  UnknownControllerException(String message) : super('unknown_controller', message);
}

class FerrostarInternalException extends FerrostarException {
  FerrostarInternalException(String message) : super('ferrostar_error', message);
}
```

- [ ] **Step 2: Controller**

```dart
// lib/src/controller.dart
import 'dart:async';
import 'ferrostar_flutter_platform.dart';
import 'models/navigation_state.dart';
import 'models/route_deviation.dart';
import 'models/spoken_instruction.dart';
import 'models/user_location.dart';

class FerrostarController {
  FerrostarController._(this._id, this._platform);

  final String _id;
  final FerrostarFlutterPlatform _platform;
  bool _disposed = false;

  String get id => _id;

  Stream<NavigationState> get stateStream =>
      _platform.stateStream(controllerId: _id);

  Stream<SpokenInstruction> get spokenInstructionStream =>
      _platform.spokenInstructionStream(controllerId: _id);

  Stream<RouteDeviation> get deviationStream =>
      _platform.deviationStream(controllerId: _id);

  Future<void> updateLocation(UserLocation location) {
    _requireAlive();
    return _platform.updateLocation(controllerId: _id, location: location);
  }

  Future<void> replaceRoute(Map<String, dynamic> osrmJson) {
    _requireAlive();
    return _platform.replaceRoute(controllerId: _id, osrmJson: osrmJson);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _platform.dispose(controllerId: _id);
  }

  void _requireAlive() {
    if (_disposed) {
      throw StateError('FerrostarController($_id) already disposed');
    }
  }
}
```

- [ ] **Step 3: Top-level facade**

```dart
// lib/src/ferrostar_flutter.dart
import 'controller.dart';
import 'ferrostar_flutter_platform.dart';
import 'models/navigation_config.dart';
import 'models/waypoint_input.dart';

class FerrostarFlutter {
  FerrostarFlutter._();
  static final FerrostarFlutter instance = FerrostarFlutter._();

  Future<FerrostarController> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    NavigationConfig config = const NavigationConfig(),
  }) async {
    final platform = FerrostarFlutterPlatform.instance;
    final id = await platform.createController(
      osrmJson: osrmJson,
      waypoints: waypoints,
      config: config,
    );
    return FerrostarControllerFactory.fromId(id, platform);
  }
}

// Internal factory so test fakes can construct controllers with arbitrary ids.
class FerrostarControllerFactory {
  static FerrostarController fromId(String id, FerrostarFlutterPlatform p) =>
      // ignore: invalid_use_of_visible_for_testing_member
      _makeController(id, p);
}

// Private constructor indirection — keeps `FerrostarController._` sealed to the
// plugin package while still letting us construct one from the facade.
FerrostarController _makeController(String id, FerrostarFlutterPlatform p) {
  return (FerrostarController as dynamic).call(id, p);
}
```

*Note:* the indirection is awkward; the simpler way is to expose a package-private constructor. Fix in the next refinement — for now, change `FerrostarController._` to `FerrostarController` and use it directly:

```dart
// Revised lib/src/controller.dart constructor signature:
FerrostarController(this._id, this._platform);
```

And revised facade:

```dart
class FerrostarFlutter {
  FerrostarFlutter._();
  static final FerrostarFlutter instance = FerrostarFlutter._();

  Future<FerrostarController> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    NavigationConfig config = const NavigationConfig(),
  }) async {
    final platform = FerrostarFlutterPlatform.instance;
    final id = await platform.createController(
      osrmJson: osrmJson,
      waypoints: waypoints,
      config: config,
    );
    return FerrostarController(id, platform);
  }
}
```

- [ ] **Step 4: Barrel export**

```dart
// lib/ferrostar_flutter.dart
export 'src/controller.dart';
export 'src/exceptions.dart';
export 'src/ferrostar_flutter.dart';
export 'src/ferrostar_flutter_platform.dart' hide FerrostarFlutterPlatform;
export 'src/models/navigation_config.dart';
export 'src/models/navigation_state.dart';
export 'src/models/route_deviation.dart';
export 'src/models/spoken_instruction.dart';
export 'src/models/trip_progress.dart';
export 'src/models/user_location.dart';
export 'src/models/visual_instruction.dart';
export 'src/models/waypoint_input.dart';
```

- [ ] **Step 5: Controller test (fake platform)**

```dart
// test/controller_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:ferrostar_flutter/src/ferrostar_flutter_platform.dart';

class _FakePlatform extends FerrostarFlutterPlatform {
  String? lastCall;
  final stateCtrl = StreamController<NavigationState>.broadcast();
  final spokenCtrl = StreamController<SpokenInstruction>.broadcast();
  final devCtrl = StreamController<RouteDeviation>.broadcast();

  @override
  Future<String> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    required NavigationConfig config,
  }) async {
    lastCall = 'createController';
    return 'test-id';
  }

  @override
  Future<void> updateLocation({
    required String controllerId,
    required UserLocation location,
  }) async => lastCall = 'updateLocation';

  @override
  Future<void> replaceRoute({
    required String controllerId,
    required Map<String, dynamic> osrmJson,
  }) async => lastCall = 'replaceRoute';

  @override
  Future<void> dispose({required String controllerId}) async {
    lastCall = 'dispose';
    await stateCtrl.close();
    await spokenCtrl.close();
    await devCtrl.close();
  }

  @override
  Stream<NavigationState> stateStream({required String controllerId}) =>
      stateCtrl.stream;
  @override
  Stream<SpokenInstruction> spokenInstructionStream({required String controllerId}) =>
      spokenCtrl.stream;
  @override
  Stream<RouteDeviation> deviationStream({required String controllerId}) =>
      devCtrl.stream;
}

void main() {
  late _FakePlatform fake;

  setUp(() {
    fake = _FakePlatform();
    FerrostarFlutterPlatform.instance = fake;
  });

  test('createController goes through facade', () async {
    final c = await FerrostarFlutter.instance.createController(
      osrmJson: {'code': 'Ok', 'routes': []},
      waypoints: [const WaypointInput(lat: 52.52, lng: 13.405)],
    );
    expect(c.id, 'test-id');
    expect(fake.lastCall, 'createController');
  });

  test('updateLocation after dispose throws StateError', () async {
    final c = await FerrostarFlutter.instance.createController(
      osrmJson: {'code': 'Ok', 'routes': []},
      waypoints: [const WaypointInput(lat: 52.52, lng: 13.405)],
    );
    await c.dispose();
    expect(
      () => c.updateLocation(const UserLocation(
        lat: 0, lng: 0, horizontalAccuracyM: 1, timestampMs: 0,
      )),
      throwsStateError,
    );
  });
}
```

- [ ] **Step 6: Run all Dart tests**

```bash
cd packages/ferrostar_flutter
flutter test
```
Expected: all tests pass, including the new controller test.

- [ ] **Step 7: Commit**

```bash
git add packages/ferrostar_flutter/lib \
  packages/ferrostar_flutter/test/controller_test.dart
git commit -m "feat(plugin): public FerrostarFlutter/FerrostarController API + tests"
```

---

## Phase 5: iOS Native Bridge

The iOS bridge owns the actual `NavigationController` instances and streams state back to Dart over the EventChannels.

### Task 17: iOS controller registry

**Files:**
- Create: `packages/ferrostar_flutter/ios/Classes/ControllerRegistry.swift`

- [ ] **Step 1: Implement**

```swift
// ios/Classes/ControllerRegistry.swift
import Foundation
import FerrostarCore
import Flutter

/// Owns native NavigationController instances keyed by UUID string so Dart
/// can refer to them without sending the heavy underlying objects across the
/// method channel.
final class ControllerRegistry {
  static let shared = ControllerRegistry()

  struct Entry {
    let controller: NavigationController
    let stateSink: FlutterEventSink?
    let spokenSink: FlutterEventSink?
    let deviationSink: FlutterEventSink?
    var lastState: NavState?
  }

  private let queue = DispatchQueue(label: "ferrostar_flutter.registry")
  private var entries: [String: Entry] = [:]

  func register(controller: NavigationController) -> String {
    let id = UUID().uuidString
    queue.sync {
      entries[id] = Entry(
        controller: controller,
        stateSink: nil, spokenSink: nil, deviationSink: nil, lastState: nil
      )
    }
    return id
  }

  func get(_ id: String) -> Entry? { queue.sync { entries[id] } }

  func update(_ id: String, mutator: (inout Entry) -> Void) {
    queue.sync {
      if var e = entries[id] { mutator(&e); entries[id] = e }
    }
  }

  @discardableResult
  func remove(_ id: String) -> Entry? { queue.sync { entries.removeValue(forKey: id) } }
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes/ControllerRegistry.swift
git commit -m "feat(plugin,ios): ControllerRegistry for handle-id lookup"
```

---

### Task 18: iOS `Serialization.swift` — JSON ↔ Ferrostar types

**Files:**
- Create: `packages/ferrostar_flutter/ios/Classes/Serialization.swift`

- [ ] **Step 1: Implement**

```swift
// ios/Classes/Serialization.swift
import Foundation
import FerrostarCore
import FerrostarCoreFFI

enum Serialization {

  // MARK: UserLocation (Dart -> Swift)

  static func decodeUserLocation(_ dict: [String: Any]) throws -> UserLocation {
    guard let lat = dict["lat"] as? Double,
          let lng = dict["lng"] as? Double,
          let acc = dict["horizontal_accuracy_m"] as? Double,
          let tsMs = dict["timestamp_ms"] as? Int else {
      throw SerializationError.missingField("lat/lng/horizontal_accuracy_m/timestamp_ms")
    }
    let course: CourseOverGround? = (dict["course_deg"] as? Double).map {
      CourseOverGround(degrees: UInt16($0), accuracy: nil)
    }
    let speed: Speed? = (dict["speed_mps"] as? Double).map {
      Speed(value: $0, accuracy: nil)
    }
    return UserLocation(
      coordinates: GeographicCoordinate(lat: lat, lng: lng),
      horizontalAccuracy: acc,
      courseOverGround: course,
      timestamp: Date(timeIntervalSince1970: Double(tsMs) / 1000),
      speed: speed
    )
  }

  // MARK: NavigationState (Swift -> Dart)

  static func encodeNavigationState(_ tripState: TripState, isOffRoute: Bool) -> [String: Any?] {
    switch tripState {
    case .idle:
      return [
        "status": "idle",
        "is_off_route": false,
        "snapped_location": nil,
        "progress": nil,
        "current_visual": nil,
        "current_step": nil,
      ]
    case .complete:
      return [
        "status": "complete",
        "is_off_route": false,
        "snapped_location": nil,
        "progress": nil,
        "current_visual": nil,
        "current_step": nil,
      ]
    case .navigating(let nav):
      return [
        "status": "navigating",
        "is_off_route": isOffRoute,
        "snapped_location": encodeUserLocation(nav.snappedUserLocation),
        "progress": encodeTripProgress(nav.progress),
        "current_visual": encodeVisualInstruction(nav.visualInstruction),
        "current_step": encodeStepRef(index: nav.currentStepIndex, step: nav.currentStep),
      ]
    }
  }

  static func encodeUserLocation(_ loc: UserLocation) -> [String: Any?] {
    return [
      "lat": loc.coordinates.lat,
      "lng": loc.coordinates.lng,
      "horizontal_accuracy_m": loc.horizontalAccuracy,
      "course_deg": loc.courseOverGround.map { Double($0.degrees) },
      "speed_mps": loc.speed?.value,
      "timestamp_ms": Int(loc.timestamp.timeIntervalSince1970 * 1000),
    ]
  }

  static func encodeTripProgress(_ p: TripProgress) -> [String: Any?] {
    return [
      "distance_to_next_maneuver_m": p.distanceToNextManeuver,
      "distance_remaining_m": p.distanceRemaining,
      "duration_remaining_ms": Int(p.durationRemaining * 1000),
    ]
  }

  static func encodeVisualInstruction(_ v: VisualInstruction?) -> [String: Any?]? {
    guard let v = v else { return nil }
    return [
      "primary_text": v.primaryContent.text,
      "secondary_text": v.secondaryContent?.text,
      "maneuver_type": v.primaryContent.maneuverType?.rawValue ?? "unknown",
      "maneuver_modifier": v.primaryContent.maneuverModifier?.rawValue,
      "trigger_distance_m": v.triggerDistanceBeforeManeuver,
    ]
  }

  static func encodeStepRef(index: Int, step: RouteStep) -> [String: Any?] {
    return ["index": index, "road_name": step.roadName]
  }

  // MARK: SpokenInstruction (Swift -> Dart)

  static func encodeSpokenInstruction(_ s: SpokenInstruction) -> [String: Any?] {
    return [
      "uuid": s.utteranceId.uuidString,
      "text": s.text,
      "ssml": s.ssml,
      "trigger_distance_m": s.triggerDistanceBeforeManeuver,
      "emitted_at_ms": Int(Date().timeIntervalSince1970 * 1000),
    ]
  }

  // MARK: RouteDeviation (Swift -> Dart)

  static func encodeDeviation(deviationMeters: Double, durationMs: Int, location: UserLocation) -> [String: Any?] {
    return [
      "deviation_m": deviationMeters,
      "duration_off_route_ms": durationMs,
      "user_location": encodeUserLocation(location),
    ]
  }

  enum SerializationError: Error {
    case missingField(String)
  }
}
```

- [ ] **Step 2: Check it builds**

```bash
cd packages/ferrostar_flutter/example
flutter build ios --no-codesign --simulator
```
Expected: builds. Any Ferrostar API drift (e.g., `visualInstruction` actually being at a different path on `nav`) surfaces here — consult the current Swift bindings and fix before proceeding.

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes/Serialization.swift
git commit -m "feat(plugin,ios): Swift <-> Dart JSON serialization"
```

---

### Task 19: iOS StreamEmitters (EventChannel handlers)

**Files:**
- Create: `packages/ferrostar_flutter/ios/Classes/StreamEmitters.swift`

- [ ] **Step 1: Implement**

```swift
// ios/Classes/StreamEmitters.swift
import Flutter

/// Registers one EventChannel per (controller_id, kind) tuple, capturing the
/// FlutterEventSink in the ControllerRegistry so native callbacks can dispatch
/// events to the right Dart stream.
final class StreamEmitters: NSObject {

  enum Kind { case state, spoken, deviation }

  static func register(
    controllerId: String,
    kind: Kind,
    messenger: FlutterBinaryMessenger
  ) {
    let base = "land._001/ferrostar_flutter"
    let name: String
    switch kind {
    case .state: name = "\(base)/state/\(controllerId)"
    case .spoken: name = "\(base)/spoken/\(controllerId)"
    case .deviation: name = "\(base)/deviation/\(controllerId)"
    }
    let channel = FlutterEventChannel(name: name, binaryMessenger: messenger)
    let handler = Handler(controllerId: controllerId, kind: kind)
    channel.setStreamHandler(handler)
  }

  final class Handler: NSObject, FlutterStreamHandler {
    let controllerId: String
    let kind: Kind
    init(controllerId: String, kind: Kind) {
      self.controllerId = controllerId
      self.kind = kind
    }
    func onListen(withArguments _: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
      ControllerRegistry.shared.update(controllerId) { entry in
        switch kind {
        case .state: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: eventSink,
            spokenSink: entry.spokenSink, deviationSink: entry.deviationSink,
            lastState: entry.lastState)
        case .spoken: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: entry.stateSink,
            spokenSink: eventSink, deviationSink: entry.deviationSink,
            lastState: entry.lastState)
        case .deviation: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: entry.stateSink,
            spokenSink: entry.spokenSink, deviationSink: eventSink,
            lastState: entry.lastState)
        }
      }
      return nil
    }
    func onCancel(withArguments _: Any?) -> FlutterError? {
      ControllerRegistry.shared.update(controllerId) { entry in
        switch kind {
        case .state: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: nil,
            spokenSink: entry.spokenSink, deviationSink: entry.deviationSink,
            lastState: entry.lastState)
        case .spoken: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: entry.stateSink,
            spokenSink: nil, deviationSink: entry.deviationSink,
            lastState: entry.lastState)
        case .deviation: entry = ControllerRegistry.Entry(
            controller: entry.controller, stateSink: entry.stateSink,
            spokenSink: entry.spokenSink, deviationSink: nil,
            lastState: entry.lastState)
        }
      }
      return nil
    }
  }
}
```

*(The `Entry` reconstruction above is verbose because Swift structs don't mutate fields easily through `inout`; a real implementation should replace this with a reference-typed Entry or mutable struct fields. Apply that refactor when touching this file — see "Refinement notes" at end of this plan.)*

- [ ] **Step 2: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes/StreamEmitters.swift
git commit -m "feat(plugin,ios): EventChannel handlers for state/spoken/deviation streams"
```

---

### Task 20: iOS `ControllerBridge.swift` — main method channel handler

**Files:**
- Create: `packages/ferrostar_flutter/ios/Classes/ControllerBridge.swift`

- [ ] **Step 1: Implement**

```swift
// ios/Classes/ControllerBridge.swift
import Flutter
import FerrostarCore
import FerrostarCoreFFI

final class ControllerBridge {

  static func handle(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    messenger: FlutterBinaryMessenger
  ) {
    switch call.method {
    case "createController": createController(args: call.arguments, result: result, messenger: messenger)
    case "updateLocation": updateLocation(args: call.arguments, result: result)
    case "replaceRoute": replaceRoute(args: call.arguments, result: result)
    case "dispose": dispose(args: call.arguments, result: result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private static func createController(
    args: Any?, result: @escaping FlutterResult, messenger: FlutterBinaryMessenger
  ) {
    guard let dict = args as? [String: Any],
          let osrm = dict["osrm_json"] as? [String: Any],
          let waypointsJson = dict["waypoints"] as? [[String: Any]],
          let configJson = dict["config"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "createController: bad args", details: nil))
      return
    }

    do {
      // Encode to Data, hand to Ferrostar's OSRM parser.
      let jsonData = try JSONSerialization.data(withJSONObject: osrm)
      let waypoints: [Waypoint] = try waypointsJson.map { try Serialization.decodeWaypoint($0) }
      let route = try createRouteFromOsrmRoute(
        osrmRouteData: jsonData,
        waypoints: waypoints,
        polylinePrecision: 6
      )

      let config = try Serialization.decodeConfig(configJson)
      let controller = NavigationController(route: route, config: config)

      let id = ControllerRegistry.shared.register(controller: controller)

      // Register streams for this controller.
      StreamEmitters.register(controllerId: id, kind: .state, messenger: messenger)
      StreamEmitters.register(controllerId: id, kind: .spoken, messenger: messenger)
      StreamEmitters.register(controllerId: id, kind: .deviation, messenger: messenger)

      result(id)
    } catch let err as Serialization.SerializationError {
      result(FlutterError(code: "route_parse_failed", message: String(describing: err), details: nil))
    } catch {
      result(FlutterError(code: "ferrostar_error", message: "\(error)", details: nil))
    }
  }

  private static func updateLocation(args: Any?, result: @escaping FlutterResult) {
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String,
          let locDict = dict["location"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "updateLocation: bad args", details: nil))
      return
    }
    guard let entry = ControllerRegistry.shared.get(id) else {
      result(FlutterError(code: "unknown_controller", message: id, details: nil))
      return
    }
    do {
      let loc = try Serialization.decodeUserLocation(locDict)
      // Ferrostar pattern: get current state or initial state, then update.
      let newState: NavState
      if let last = entry.lastState {
        newState = entry.controller.updateUserLocation(location: loc, state: last)
      } else {
        newState = entry.controller.getInitialState(location: loc)
      }

      ControllerRegistry.shared.update(id) { e in
        e = ControllerRegistry.Entry(
          controller: e.controller,
          stateSink: e.stateSink,
          spokenSink: e.spokenSink,
          deviationSink: e.deviationSink,
          lastState: newState
        )
      }

      // Emit state, spoken instructions, and deviation events.
      let isOffRoute = (newState.tripState.unwrapNavigating()?.routeDeviation) != nil
      if let sink = entry.stateSink {
        sink(Serialization.encodeNavigationState(newState.tripState, isOffRoute: isOffRoute))
      }
      if let spokenSink = entry.spokenSink,
         case .navigating(let nav) = newState.tripState,
         let spoken = nav.spokenInstruction {
        spokenSink(Serialization.encodeSpokenInstruction(spoken))
      }
      if let devSink = entry.deviationSink,
         case .navigating(let nav) = newState.tripState,
         let dev = nav.routeDeviation {
        devSink(Serialization.encodeDeviation(
          deviationMeters: dev.deviationFromRouteLine,
          durationMs: 0, // Ferrostar does not track duration directly; set 0 for v0.1.
          location: loc
        ))
      }

      result(nil)
    } catch {
      result(FlutterError(code: "invalid_argument", message: "\(error)", details: nil))
    }
  }

  private static func replaceRoute(args: Any?, result: @escaping FlutterResult) {
    // v0.1: simplest replacement — create new NavigationController with new route,
    // swap it in the registry. Streams stay attached.
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String,
          let osrm = dict["osrm_json"] as? [String: Any] else {
      result(FlutterError(code: "invalid_argument", message: "replaceRoute: bad args", details: nil))
      return
    }
    guard let entry = ControllerRegistry.shared.get(id) else {
      result(FlutterError(code: "unknown_controller", message: id, details: nil))
      return
    }
    do {
      let jsonData = try JSONSerialization.data(withJSONObject: osrm)
      let route = try createRouteFromOsrmRoute(
        osrmRouteData: jsonData,
        waypoints: [],
        polylinePrecision: 6
      )
      let newController = NavigationController(route: route, config: entry.controller.config)
      ControllerRegistry.shared.update(id) { e in
        e = ControllerRegistry.Entry(
          controller: newController,
          stateSink: e.stateSink,
          spokenSink: e.spokenSink,
          deviationSink: e.deviationSink,
          lastState: nil
        )
      }
      result(nil)
    } catch {
      result(FlutterError(code: "route_parse_failed", message: "\(error)", details: nil))
    }
  }

  private static func dispose(args: Any?, result: @escaping FlutterResult) {
    guard let dict = args as? [String: Any],
          let id = dict["controller_id"] as? String else {
      result(FlutterError(code: "invalid_argument", message: "dispose: bad args", details: nil))
      return
    }
    ControllerRegistry.shared.remove(id)
    result(nil)
  }
}
```

- [ ] **Step 2: Add Serialization helpers referenced above**

Append to `Serialization.swift`:

```swift
extension Serialization {
  static func decodeWaypoint(_ dict: [String: Any]) throws -> Waypoint {
    guard let lat = dict["lat"] as? Double, let lng = dict["lng"] as? Double else {
      throw SerializationError.missingField("lat/lng")
    }
    let kindStr = (dict["kind"] as? String) ?? "break"
    let kind: WaypointKind = (kindStr == "via_point") ? .viaPoint : .breakPoint
    return Waypoint(
      coordinate: GeographicCoordinate(lat: lat, lng: lng),
      kind: kind
    )
  }

  static func decodeConfig(_ dict: [String: Any]) throws -> NavigationControllerConfig {
    let devM = (dict["deviation_threshold_m"] as? Double) ?? 50.0
    let snap = (dict["snap_user_location_to_route"] as? Bool) ?? true
    // Use Ferrostar's default route deviation detector keyed off devM.
    return NavigationControllerConfig(
      waypointAdvance: .waypointWithinRange(distance: 20.0),
      stepAdvanceCondition: .distanceToEndOfStep(distance: 10, minimumHorizontalAccuracy: 32),
      routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 25, maxAcceptableDeviation: devM),
      snappedLocationCourseFiltering: snap ? .snapToRoute : .raw
    )
  }
}
```

- [ ] **Step 3: Build, verify**

```bash
cd packages/ferrostar_flutter/example
flutter build ios --no-codesign --simulator
```

- [ ] **Step 4: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes
git commit -m "feat(plugin,ios): ControllerBridge wiring createController/updateLocation/replaceRoute/dispose"
```

---

### Task 21: iOS `FerrostarFlutterPlugin.swift` — plugin entry routing

**Files:**
- Modify: `packages/ferrostar_flutter/ios/Classes/FerrostarFlutterPlugin.swift`

- [ ] **Step 1: Replace the smoke-test stub with the real handler**

```swift
// ios/Classes/FerrostarFlutterPlugin.swift
import Flutter
import UIKit

public class FerrostarFlutterPlugin: NSObject, FlutterPlugin {
  private static var sharedMessenger: FlutterBinaryMessenger?

  public static func register(with registrar: FlutterPluginRegistrar) {
    sharedMessenger = registrar.messenger()
    let channel = FlutterMethodChannel(
      name: "land._001/ferrostar_flutter",
      binaryMessenger: registrar.messenger()
    )
    let instance = FerrostarFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let messenger = FerrostarFlutterPlugin.sharedMessenger else {
      result(FlutterError(code: "internal", message: "No binary messenger", details: nil))
      return
    }
    ControllerBridge.handle(call: call, result: result, messenger: messenger)
  }
}
```

- [ ] **Step 2: Build**

```bash
cd packages/ferrostar_flutter/example
flutter build ios --no-codesign --simulator
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes/FerrostarFlutterPlugin.swift
git commit -m "feat(plugin,ios): wire ControllerBridge into plugin entry"
```

---

### Task 22: iOS manual end-to-end test in example app

**Files:**
- Modify: `packages/ferrostar_flutter/example/lib/main.dart`
- Create: `packages/ferrostar_flutter/example/assets/sample_osrm_route.json`

- [ ] **Step 1: Fetch a sample OSRM route**

Grab a sample Mapbox Directions v5 response (Ferrostar's test fixtures include one). Save under `example/assets/sample_osrm_route.json`:

```bash
curl -sSL https://raw.githubusercontent.com/stadiamaps/ferrostar/main/common/ferrostar/fixtures/valhalla-osrm-short.json \
  -o packages/ferrostar_flutter/example/assets/sample_osrm_route.json
```

- [ ] **Step 2: Add the asset to pubspec**

Edit `packages/ferrostar_flutter/example/pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/sample_osrm_route.json
```

- [ ] **Step 3: Replace `example/lib/main.dart` with an e2e smoke test UI**

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';

void main() => runApp(const MaterialApp(home: E2EHome()));

class E2EHome extends StatefulWidget {
  const E2EHome({super.key});
  @override
  State<E2EHome> createState() => _E2EHomeState();
}

class _E2EHomeState extends State<E2EHome> {
  FerrostarController? _ctrl;
  NavigationState? _state;
  String _log = '';

  Future<void> _start() async {
    final jsonStr = await rootBundle.loadString('assets/sample_osrm_route.json');
    final osrm = json.decode(jsonStr) as Map<String, dynamic>;

    final ctrl = await FerrostarFlutter.instance.createController(
      osrmJson: osrm,
      waypoints: [
        const WaypointInput(lat: 52.52, lng: 13.405),
        const WaypointInput(lat: 52.50, lng: 13.40),
      ],
    );
    ctrl.stateStream.listen((s) => setState(() => _state = s));
    ctrl.spokenInstructionStream.listen(
        (s) => setState(() => _log = 'SPOKEN: ${s.text}'));
    ctrl.deviationStream.listen(
        (d) => setState(() => _log = 'DEVIATION: ${d.deviationM}m'));
    setState(() => _ctrl = ctrl);
  }

  Future<void> _tick() async {
    // Simulate location along the first coordinate of the route.
    await _ctrl?.updateLocation(UserLocation(
      lat: 52.519, lng: 13.404,
      horizontalAccuracyM: 5.0,
      courseDeg: 45.0,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
        appBar: AppBar(title: const Text('ferrostar_flutter E2E')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton(onPressed: _start, child: const Text('Start')),
            ElevatedButton(onPressed: _tick, child: const Text('Send location')),
            const SizedBox(height: 16),
            Text('State: ${_state?.status ?? "(none)"}'),
            if (_state?.currentVisual != null)
              Text('Instruction: ${_state!.currentVisual!.primaryText}'),
            if (_state?.progress != null)
              Text('Distance remaining: ${_state!.progress!.distanceRemainingM.toStringAsFixed(0)}m'),
            const SizedBox(height: 16),
            Text('Log: $_log'),
          ]),
        ),
      );
}
```

- [ ] **Step 4: Run on iOS simulator**

```bash
cd packages/ferrostar_flutter/example
flutter run -d "iPhone 15"  # or whichever simulator is available
```

Tap "Start", then "Send location". Expected:
- `State` becomes `TripStatus.navigating`
- `Instruction` shows the current maneuver from the sample route
- `Distance remaining` shows a numeric value

If any of these don't update, check the iOS device logs (`flutter logs`) for FerrostarCore errors.

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/example/lib/main.dart \
  packages/ferrostar_flutter/example/pubspec.yaml \
  packages/ferrostar_flutter/example/assets/sample_osrm_route.json
git commit -m "test(plugin,ios): end-to-end smoke test in example app"
```

---

## Phase 6: Android Native Bridge

Mirror the iOS bridge in Kotlin. Tasks follow the same shape.

### Task 23: Android `ControllerRegistry.kt`

**Files:**
- Create: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/ControllerRegistry.kt`

- [ ] **Step 1: Implement**

```kotlin
// android/.../ControllerRegistry.kt
package land._001.ferrostar_flutter

import com.stadiamaps.ferrostar.core.NavigationController
import com.stadiamaps.ferrostar.core.NavState
import io.flutter.plugin.common.EventChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

object ControllerRegistry {
  data class Entry(
    val controller: NavigationController,
    var stateSink: EventChannel.EventSink? = null,
    var spokenSink: EventChannel.EventSink? = null,
    var deviationSink: EventChannel.EventSink? = null,
    var lastState: NavState? = null,
  )

  private val entries = ConcurrentHashMap<String, Entry>()

  fun register(controller: NavigationController): String {
    val id = UUID.randomUUID().toString()
    entries[id] = Entry(controller)
    return id
  }

  fun get(id: String): Entry? = entries[id]

  fun remove(id: String): Entry? = entries.remove(id)
}
```

- [ ] **Step 2: Commit**

```bash
git add packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/ControllerRegistry.kt
git commit -m "feat(plugin,android): ControllerRegistry"
```

---

### Task 24: Android `Serialization.kt`

**Files:**
- Create: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/Serialization.kt`

- [ ] **Step 1: Implement**

```kotlin
// android/.../Serialization.kt
package land._001.ferrostar_flutter

import com.stadiamaps.ferrostar.core.*
import java.time.Instant

object Serialization {

  // Dart -> Kotlin

  fun decodeUserLocation(m: Map<String, Any?>): UserLocation {
    val lat = (m["lat"] as Number).toDouble()
    val lng = (m["lng"] as Number).toDouble()
    val acc = (m["horizontal_accuracy_m"] as Number).toDouble()
    val ts  = (m["timestamp_ms"] as Number).toLong()
    val course = (m["course_deg"] as? Number)?.let {
      CourseOverGround(degrees = it.toInt().toUShort(), accuracy = null)
    }
    val speed = (m["speed_mps"] as? Number)?.let {
      Speed(value = it.toDouble(), accuracy = null)
    }
    return UserLocation(
      coordinates = GeographicCoordinate(lat, lng),
      horizontalAccuracy = acc,
      courseOverGround = course,
      timestamp = Instant.ofEpochMilli(ts),
      speed = speed,
    )
  }

  fun decodeWaypoint(m: Map<String, Any?>): Waypoint {
    val lat = (m["lat"] as Number).toDouble()
    val lng = (m["lng"] as Number).toDouble()
    val kind = when (m["kind"] as? String) {
      "via_point" -> WaypointKind.VIA_POINT
      else -> WaypointKind.BREAK
    }
    return Waypoint(GeographicCoordinate(lat, lng), kind)
  }

  fun decodeConfig(m: Map<String, Any?>): NavigationControllerConfig {
    val devM = (m["deviation_threshold_m"] as? Number)?.toDouble() ?: 50.0
    val snap = (m["snap_user_location_to_route"] as? Boolean) ?: true
    return NavigationControllerConfig(
      waypointAdvance = WaypointAdvanceMode.WaypointWithinRange(20.0),
      stepAdvanceCondition = StepAdvanceCondition.DistanceToEndOfStep(10u, 32u),
      routeDeviationTracking = RouteDeviationTracking.StaticThreshold(25u, devM),
      snappedLocationCourseFiltering = if (snap) CourseFiltering.SnapToRoute else CourseFiltering.Raw,
    )
  }

  // Kotlin -> Dart

  fun encodeNavigationState(tripState: TripState, isOffRoute: Boolean): Map<String, Any?> {
    return when (tripState) {
      is TripState.Idle -> mapOf(
        "status" to "idle", "is_off_route" to false,
        "snapped_location" to null, "progress" to null,
        "current_visual" to null, "current_step" to null,
      )
      is TripState.Complete -> mapOf(
        "status" to "complete", "is_off_route" to false,
        "snapped_location" to null, "progress" to null,
        "current_visual" to null, "current_step" to null,
      )
      is TripState.Navigating -> mapOf(
        "status" to "navigating",
        "is_off_route" to isOffRoute,
        "snapped_location" to encodeUserLocation(tripState.snappedUserLocation),
        "progress" to encodeTripProgress(tripState.progress),
        "current_visual" to tripState.visualInstruction?.let { encodeVisualInstruction(it) },
        "current_step" to mapOf(
          "index" to tripState.currentStepIndex,
          "road_name" to tripState.currentStep.roadName,
        ),
      )
    }
  }

  fun encodeUserLocation(loc: UserLocation): Map<String, Any?> = mapOf(
    "lat" to loc.coordinates.lat,
    "lng" to loc.coordinates.lng,
    "horizontal_accuracy_m" to loc.horizontalAccuracy,
    "course_deg" to loc.courseOverGround?.degrees?.toDouble(),
    "speed_mps" to loc.speed?.value,
    "timestamp_ms" to loc.timestamp.toEpochMilli(),
  )

  fun encodeTripProgress(p: TripProgress): Map<String, Any?> = mapOf(
    "distance_to_next_maneuver_m" to p.distanceToNextManeuver,
    "distance_remaining_m" to p.distanceRemaining,
    "duration_remaining_ms" to (p.durationRemaining * 1000).toLong(),
  )

  fun encodeVisualInstruction(v: VisualInstruction): Map<String, Any?> = mapOf(
    "primary_text" to v.primaryContent.text,
    "secondary_text" to v.secondaryContent?.text,
    "maneuver_type" to (v.primaryContent.maneuverType?.name?.lowercase() ?: "unknown"),
    "maneuver_modifier" to v.primaryContent.maneuverModifier?.name?.lowercase(),
    "trigger_distance_m" to v.triggerDistanceBeforeManeuver,
  )

  fun encodeSpokenInstruction(s: SpokenInstruction): Map<String, Any?> = mapOf(
    "uuid" to s.utteranceId.toString(),
    "text" to s.text,
    "ssml" to s.ssml,
    "trigger_distance_m" to s.triggerDistanceBeforeManeuver,
    "emitted_at_ms" to System.currentTimeMillis(),
  )

  fun encodeDeviation(
    deviationM: Double, durationMs: Long, location: UserLocation
  ): Map<String, Any?> = mapOf(
    "deviation_m" to deviationM,
    "duration_off_route_ms" to durationMs,
    "user_location" to encodeUserLocation(location),
  )
}
```

- [ ] **Step 2: Build**

```bash
cd packages/ferrostar_flutter/example
flutter build apk --debug
```

- [ ] **Step 3: Commit**

```bash
git add packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/Serialization.kt
git commit -m "feat(plugin,android): Kotlin <-> Dart serialization"
```

---

### Task 25: Android `StreamEmitters.kt` + `ControllerBridge.kt`

**Files:**
- Create: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/StreamEmitters.kt`
- Create: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/ControllerBridge.kt`

- [ ] **Step 1: StreamEmitters**

```kotlin
// android/.../StreamEmitters.kt
package land._001.ferrostar_flutter

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

object StreamEmitters {
  enum class Kind { STATE, SPOKEN, DEVIATION }

  fun register(controllerId: String, kind: Kind, messenger: BinaryMessenger) {
    val base = "land._001/ferrostar_flutter"
    val name = when (kind) {
      Kind.STATE -> "$base/state/$controllerId"
      Kind.SPOKEN -> "$base/spoken/$controllerId"
      Kind.DEVIATION -> "$base/deviation/$controllerId"
    }
    val channel = EventChannel(messenger, name)
    channel.setStreamHandler(object : EventChannel.StreamHandler {
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        val entry = ControllerRegistry.get(controllerId) ?: return
        when (kind) {
          Kind.STATE -> entry.stateSink = events
          Kind.SPOKEN -> entry.spokenSink = events
          Kind.DEVIATION -> entry.deviationSink = events
        }
      }
      override fun onCancel(arguments: Any?) {
        val entry = ControllerRegistry.get(controllerId) ?: return
        when (kind) {
          Kind.STATE -> entry.stateSink = null
          Kind.SPOKEN -> entry.spokenSink = null
          Kind.DEVIATION -> entry.deviationSink = null
        }
      }
    })
  }
}
```

- [ ] **Step 2: ControllerBridge**

```kotlin
// android/.../ControllerBridge.kt
package land._001.ferrostar_flutter

import com.stadiamaps.ferrostar.core.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

object ControllerBridge {

  fun handle(call: MethodCall, result: MethodChannel.Result, messenger: BinaryMessenger) {
    when (call.method) {
      "createController" -> createController(call.arguments, result, messenger)
      "updateLocation" -> updateLocation(call.arguments, result)
      "replaceRoute" -> replaceRoute(call.arguments, result)
      "dispose" -> dispose(call.arguments, result)
      else -> result.notImplemented()
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun createController(args: Any?, result: MethodChannel.Result, messenger: BinaryMessenger) {
    val m = args as? Map<String, Any?> ?: run {
      return result.error("invalid_argument", "createController: bad args", null)
    }
    try {
      val osrm = m["osrm_json"] as Map<String, Any?>
      val waypoints = (m["waypoints"] as List<Map<String, Any?>>).map { Serialization.decodeWaypoint(it) }
      val config = Serialization.decodeConfig(m["config"] as Map<String, Any?>)

      val osrmBytes = JSONObject(osrm).toString().toByteArray(Charsets.UTF_8)
      val route = createRouteFromOsrmRoute(osrmBytes, waypoints, 6u)

      val controller = NavigationController(route, config)
      val id = ControllerRegistry.register(controller)

      StreamEmitters.register(id, StreamEmitters.Kind.STATE, messenger)
      StreamEmitters.register(id, StreamEmitters.Kind.SPOKEN, messenger)
      StreamEmitters.register(id, StreamEmitters.Kind.DEVIATION, messenger)

      result.success(id)
    } catch (e: Exception) {
      result.error("route_parse_failed", e.message, null)
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun updateLocation(args: Any?, result: MethodChannel.Result) {
    val m = args as? Map<String, Any?> ?: return result.error("invalid_argument", "updateLocation", null)
    val id = m["controller_id"] as String
    val entry = ControllerRegistry.get(id) ?: return result.error("unknown_controller", id, null)
    try {
      val loc = Serialization.decodeUserLocation(m["location"] as Map<String, Any?>)
      val newState = if (entry.lastState != null) {
        entry.controller.updateUserLocation(loc, entry.lastState!!)
      } else {
        entry.controller.getInitialState(loc)
      }
      entry.lastState = newState

      val nav = (newState.tripState as? TripState.Navigating)
      val isOffRoute = nav?.routeDeviation != null

      entry.stateSink?.success(Serialization.encodeNavigationState(newState.tripState, isOffRoute))
      nav?.spokenInstruction?.let { spoken ->
        entry.spokenSink?.success(Serialization.encodeSpokenInstruction(spoken))
      }
      nav?.routeDeviation?.let { dev ->
        entry.deviationSink?.success(Serialization.encodeDeviation(dev.deviationFromRouteLine, 0L, loc))
      }

      result.success(null)
    } catch (e: Exception) {
      result.error("invalid_argument", e.message, null)
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun replaceRoute(args: Any?, result: MethodChannel.Result) {
    val m = args as? Map<String, Any?> ?: return result.error("invalid_argument", "replaceRoute", null)
    val id = m["controller_id"] as String
    val entry = ControllerRegistry.get(id) ?: return result.error("unknown_controller", id, null)
    try {
      val osrm = m["osrm_json"] as Map<String, Any?>
      val bytes = JSONObject(osrm).toString().toByteArray(Charsets.UTF_8)
      val route = createRouteFromOsrmRoute(bytes, emptyList(), 6u)
      val newController = NavigationController(route, entry.controller.config)
      ControllerRegistry.remove(id)
      val newEntry = ControllerRegistry.Entry(
        controller = newController,
        stateSink = entry.stateSink,
        spokenSink = entry.spokenSink,
        deviationSink = entry.deviationSink,
        lastState = null,
      )
      // Re-register under same id:
      (ControllerRegistry.javaClass.getDeclaredField("entries").apply { isAccessible = true }.get(ControllerRegistry)
        as java.util.concurrent.ConcurrentHashMap<String, ControllerRegistry.Entry>)[id] = newEntry
      result.success(null)
    } catch (e: Exception) {
      result.error("route_parse_failed", e.message, null)
    }
  }

  @Suppress("UNCHECKED_CAST")
  private fun dispose(args: Any?, result: MethodChannel.Result) {
    val m = args as? Map<String, Any?> ?: return result.error("invalid_argument", "dispose", null)
    val id = m["controller_id"] as String
    ControllerRegistry.remove(id)
    result.success(null)
  }
}
```

*(Note: the reflection trick for replaceRoute is ugly — replace with a proper `ControllerRegistry.swap(id, newEntry)` method in refinement. Tracked in "Refinement notes".)*

- [ ] **Step 3: Wire plugin entry**

Replace `FerrostarFlutterPlugin.kt`:

```kotlin
package land._001.ferrostar_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class FerrostarFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var binding: FlutterPlugin.FlutterPluginBinding

  override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
    binding = b
    channel = MethodChannel(b.binaryMessenger, "land._001/ferrostar_flutter")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    ControllerBridge.handle(call, result, binding.binaryMessenger)
  }

  override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
```

- [ ] **Step 4: Build**

```bash
cd packages/ferrostar_flutter/example
flutter build apk --debug
```

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter
git commit -m "feat(plugin,android): ControllerBridge + StreamEmitters + plugin wiring"
```

---

### Task 26: Android manual end-to-end test in example app

**Files:** (no code changes — reuse `example/lib/main.dart` from Task 22)

- [ ] **Step 1: Boot Android emulator and run example**

```bash
cd packages/ferrostar_flutter/example
flutter run -d emulator
```

- [ ] **Step 2: Verify same behavior as iOS e2e**

Tap Start → Send location. Expect:
- State: navigating
- Instruction: populated
- Distance remaining: populated

Inspect `adb logcat | grep Ferrostar` for any crashes. Fix issues before proceeding.

- [ ] **Step 3: Tag a dev milestone**

```bash
git tag dev/0.1.0-e2e-both-platforms
```

*(No code commit needed; this just marks a checkpoint.)*

---

## Phase 7: Tests & Polish

### Task 27: Integration tests (drive both platforms)

**Files:**
- Create: `packages/ferrostar_flutter/example/integration_test/plugin_integration_test.dart`

- [ ] **Step 1: Add integration_test dev dependency**

Edit `packages/ferrostar_flutter/example/pubspec.yaml`:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

- [ ] **Step 2: Write integration test**

```dart
// example/integration_test/plugin_integration_test.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('create -> update -> receive state', (tester) async {
    final osrmStr = await rootBundle.loadString('assets/sample_osrm_route.json');
    final osrm = json.decode(osrmStr) as Map<String, dynamic>;

    final ctrl = await FerrostarFlutter.instance.createController(
      osrmJson: osrm,
      waypoints: [
        const WaypointInput(lat: 52.52, lng: 13.405),
        const WaypointInput(lat: 52.50, lng: 13.40),
      ],
    );

    final completer = ctrl.stateStream.firstWhere((s) => s.status == TripStatus.navigating);

    await ctrl.updateLocation(UserLocation(
      lat: 52.519, lng: 13.404,
      horizontalAccuracyM: 5.0,
      courseDeg: 45.0,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    ));

    final state = await completer.timeout(const Duration(seconds: 5));
    expect(state.status, TripStatus.navigating);
    expect(state.progress, isNotNull);

    await ctrl.dispose();
  });

  testWidgets('replaceRoute does not throw', (tester) async {
    final osrmStr = await rootBundle.loadString('assets/sample_osrm_route.json');
    final osrm = json.decode(osrmStr) as Map<String, dynamic>;

    final ctrl = await FerrostarFlutter.instance.createController(
      osrmJson: osrm,
      waypoints: [const WaypointInput(lat: 52.52, lng: 13.405)],
    );
    await ctrl.replaceRoute(osrm);
    await ctrl.dispose();
  });
}
```

- [ ] **Step 3: Run on iOS simulator**

```bash
cd packages/ferrostar_flutter/example
flutter test integration_test/plugin_integration_test.dart -d "iPhone 15"
```

- [ ] **Step 4: Run on Android emulator**

```bash
flutter test integration_test/plugin_integration_test.dart -d emulator
```

Both should pass.

- [ ] **Step 5: Commit**

```bash
git add packages/ferrostar_flutter/example/pubspec.yaml \
  packages/ferrostar_flutter/example/integration_test/plugin_integration_test.dart
git commit -m "test(plugin): integration test for create->update->state on both platforms"
```

---

### Task 28: Refinement pass — Swift/Kotlin code cleanup

**Files:**
- Modify: `packages/ferrostar_flutter/ios/Classes/ControllerRegistry.swift`
- Modify: `packages/ferrostar_flutter/ios/Classes/StreamEmitters.swift`
- Modify: `packages/ferrostar_flutter/android/src/main/kotlin/land/_001/ferrostar_flutter/ControllerBridge.kt`

The rough edges from Phase 5/6 — Swift struct reconstruction, Kotlin reflection in replaceRoute — need cleanup now that the whole flow works.

- [ ] **Step 1: Convert iOS `Entry` to a reference type**

In `ControllerRegistry.swift`, change:

```swift
struct Entry { … }
```

to

```swift
final class Entry {
  let controller: NavigationController
  var stateSink: FlutterEventSink?
  var spokenSink: FlutterEventSink?
  var deviationSink: FlutterEventSink?
  var lastState: NavState?
  init(controller: NavigationController) {
    self.controller = controller
    self.stateSink = nil; self.spokenSink = nil
    self.deviationSink = nil; self.lastState = nil
  }
}
```

Update callers (`StreamEmitters.swift`, `ControllerBridge.swift`) to mutate fields directly instead of rebuilding the whole struct. This removes ~40 lines of boilerplate.

- [ ] **Step 2: Add `ControllerRegistry.swap()` on Android**

In `ControllerRegistry.kt`:

```kotlin
fun swap(id: String, newController: NavigationController) {
  val old = entries[id] ?: return
  entries[id] = Entry(
    controller = newController,
    stateSink = old.stateSink,
    spokenSink = old.spokenSink,
    deviationSink = old.deviationSink,
    lastState = null,
  )
}
```

Update `ControllerBridge.replaceRoute` to call `ControllerRegistry.swap(id, newController)` — remove the reflection trick.

- [ ] **Step 3: Rebuild + re-run integration tests**

```bash
cd packages/ferrostar_flutter/example
flutter test integration_test/plugin_integration_test.dart -d "iPhone 15"
flutter test integration_test/plugin_integration_test.dart -d emulator
```
Both should still pass.

- [ ] **Step 4: Commit**

```bash
git add packages/ferrostar_flutter/ios/Classes \
  packages/ferrostar_flutter/android/src/main/kotlin
git commit -m "refactor(plugin): clean up mutable entry handling on both platforms"
```

---

### Task 29: Documentation + version tag

**Files:**
- Modify: `packages/ferrostar_flutter/README.md`
- Modify: `packages/ferrostar_flutter/CHANGELOG.md`
- Create: `packages/ferrostar_flutter/doc/usage.md`

- [ ] **Step 1: Expand README with usage**

```markdown
## Usage

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';

final osrmJson = jsonDecode(await rootBundle.loadString('route.json'));

final controller = await FerrostarFlutter.instance.createController(
  osrmJson: osrmJson as Map<String, dynamic>,
  waypoints: [
    WaypointInput(lat: origin.lat, lng: origin.lng),
    WaypointInput(lat: dest.lat, lng: dest.lng),
  ],
);

controller.stateStream.listen((state) {
  // Update UI with state.currentVisual, state.progress, etc.
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
```

- [ ] **Step 2: Changelog entry**

```markdown
## 0.1.0 - 2026-MM-DD

Initial release. Minimal wrapper around Ferrostar iOS 0.49.x and Android 0.49.x.

### Added
- `FerrostarFlutter.createController(osrmJson, waypoints, config)`
- `FerrostarController`: `updateLocation`, `replaceRoute`, `dispose`
- Streams: `stateStream`, `spokenInstructionStream`, `deviationStream`
- Data models: `NavigationState`, `UserLocation`, `TripProgress`, `VisualInstruction`, `SpokenInstruction`, `RouteDeviation`, `WaypointInput`, `NavigationConfig`
- iOS 16+ / Android API 25+

### Not included (planned for later versions)
- Navigation recording / replay
- Custom route providers (GraphHopper native / Valhalla native)
- Background navigation service
- Publishing to pub.dev
```

- [ ] **Step 3: Tag v0.1.0**

```bash
cd /Users/pv/code/ortschaft/.claude/worktrees/ferrostar-plugin
git add packages/ferrostar_flutter/README.md packages/ferrostar_flutter/CHANGELOG.md
git commit -m "docs(plugin): flesh out README usage + CHANGELOG for 0.1.0"
git tag ferrostar_flutter-v0.1.0
```

---

## Self-Review Notes

- **Spec coverage:** Plan covers every "In scope" bullet from the spec's plugin section: `createController` (Task 20), `updateLocation` (Task 20), `stateStream` (Task 15, surfaced via Task 22 e2e), `spokenInstructionStream` (Task 20), `deviationStream` (Task 20), `replaceRoute` (Task 20), `dispose` (Task 20). Out-of-scope items (recording, cache, custom route providers, background) are absent as intended.
- **Refinement notes surfaced to reader:** Swift struct/Kotlin reflection rough edges are called out at introduction (Task 19, Task 25) AND resolved in Task 28. The reader is not left wondering.
- **Sample OSRM fixture:** Depends on Ferrostar's test fixture being fetchable. If the URL 404s (repo restructure), fall back to hand-crafting a minimal OSRM response per https://docs.mapbox.com/api/navigation/directions/.
- **GraphHopper-specific validation happens in Plan C.** The plugin treats OSRM/Mapbox Directions JSON generically; whether our backend produces valid JSON is Plan B's concern, and whether our app wires it correctly is Plan C's concern.

## After This Plan

Next: Plan B (backend `/api/navigate` endpoint) and Plan C (Ortschaft mobile app). Plan C depends on both A and B; Plan B is small and can run in parallel with the later Tasks of Plan A if you want to get unblocked for Plan C sooner.
