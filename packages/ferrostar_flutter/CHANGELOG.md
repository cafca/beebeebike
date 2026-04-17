# Changelog

## 0.1.0 - 2026-04-17

Initial release. Minimal wrapper around Ferrostar iOS 0.49.x (Android seams only).

### Added

- `FerrostarFlutter.instance.createController(osrmJson, waypoints, config)`
- `FerrostarController`: `updateLocation`, `replaceRoute`, `dispose`
- Streams: `stateStream`, `spokenInstructionStream`, `deviationStream`
- Data models: `NavigationState`, `UserLocation`, `TripProgress`, `VisualInstruction`,
  `SpokenInstruction`, `RouteDeviation`, `WaypointInput`, `NavigationConfig`
- iOS 16+ via Swift Package Manager
- Android API 25+ seam stubs (full implementation deferred)

### Not included (planned for later versions)

- Navigation recording / replay
- Custom route providers
- Background navigation service
- Publishing to pub.dev
