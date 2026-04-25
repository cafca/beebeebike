import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Latest user location observed by MapLibre's CLLocationManager (the same
/// source that drives the pulsing blue dot). Written from the map's
/// `onUserLocationUpdated` callback; read when seeding navigation, picking a
/// route origin, or recentering the camera.
///
/// Decoupled from `Geolocator.getLastKnownPosition()` because that reads the
/// system-wide cache which can lag behind MapLibre's stream and produced the
/// "new route starts 20-30m back" symptom.
final userLocationProvider = StateProvider<UserLocation?>((ref) => null);
