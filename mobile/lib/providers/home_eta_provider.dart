import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/providers/location_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Coarse position stream — emits only on significant movement (≥200 m).
/// Drives periodic ETA refresh without hitting the router on every GPS tick.
final significantPositionProvider = StreamProvider<Position>((ref) {
  return Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 200,
    ),
  );
});

/// ETA in minutes from current GPS to the user's saved home. Resolves on the
/// first available fix (last-known, else first live fix) and re-resolves when
/// the user moves ≥200 m or the saved home changes. Null when no home is set.
final homeEtaMinutesProvider = FutureProvider<int?>((ref) async {
  final home = ref.watch(homeLocationProvider).valueOrNull;
  if (home == null) return null;

  final streamed = ref.watch(significantPositionProvider).valueOrNull;
  var pos = streamed;
  if (pos == null) {
    try {
      pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
    } on Object catch (_) {
      return null;
    }
  }

  final origin = Location(
    id: 'gps',
    name: 'Mein Standort',
    label: 'Mein Standort',
    lat: pos.latitude,
    lng: pos.longitude,
  );
  final destination = Location(
    id: home.id,
    name: home.name,
    label: home.label,
    lat: home.lat,
    lng: home.lng,
  );

  final preview = await ref.read(routePreviewLoaderProvider)(
    origin: origin,
    destination: destination,
  );
  return (preview.time / 60000).round();
});
