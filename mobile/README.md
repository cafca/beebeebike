# BeeBeeBike mobile

> **Platform support:** iOS only (v0.1). Android support will be added once `ferrostar_flutter` gains Android bindings.

Run locally on iOS simulator:

```bash
flutter pub get
flutter run -d ios \
  --dart-define=BEEBEEBIKE_API_BASE_URL=http://127.0.0.1:3000 \
  --dart-define=BEEBEEBIKE_TILE_STYLE_URL=http://127.0.0.1:8080/tiles/assets/styles/colorful/style.json
```

Run tests:

```bash
flutter test
```
