# iOS Integration

`FerrostarCore` is integrated via Swift Package Manager, not CocoaPods.

Why:

- `pod search FerrostarCore` does not surface a CocoaPods spec for the upstream SDK.
- The upstream Ferrostar repo publishes the iOS SDK as Swift packages with products `FerrostarCore` and `FerrostarCoreFFI`.
- Ferrostar requires iOS 16+ and Swift tools 5.9, which matches the package manifest used here.

Layout:

- Shared plugin source lives under `ios/ferrostar_flutter/Sources/ferrostar_flutter`.
- `ios/ferrostar_flutter/Package.swift` points that source tree at the Flutter framework package and the upstream Ferrostar package.
- The CocoaPods podspec is intentionally fail-fast so unsupported iOS installs stop with a clear message instead of a compiler error.

Notes:

- The plugin method `smokeTest` is the proof-of-life path used by the example app.
- The example app is now fully SwiftPM-based on iOS; the CocoaPods wiring was removed from the example project.
- iOS consumers must use Flutter 3.41+ so the plugin is linked through Swift Package Manager.
