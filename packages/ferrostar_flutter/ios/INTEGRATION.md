# iOS Integration

`FerrostarCore` is integrated via Swift Package Manager, not CocoaPods.

Why:

- `pod search FerrostarCore` does not surface a CocoaPods spec for the upstream SDK.
- The upstream Ferrostar repo publishes the iOS SDK as Swift packages with products `FerrostarCore` and `FerrostarCoreFFI`.
- Ferrostar requires iOS 16+ and Swift tools 5.9, which matches the package manifest used here.

Layout:

- Shared plugin source lives under `ios/ferrostar_flutter/Sources/ferrostar_flutter`.
- `ios/ferrostar_flutter/Package.swift` points that source tree at the Flutter framework package and the upstream Ferrostar package.
- The CocoaPods podspec keeps the same source tree so the plugin stays in one place.

Notes:

- The plugin method `smokeTest` is the proof-of-life path used by the example app.
- The example app still keeps CocoaPods for Flutter-managed dependencies, but the plugin itself exposes a Swift package so Flutter can migrate the app project to Swift Package Manager for plugin linking.
