import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/berlin_bounds.dart';
import 'auth_provider.dart';
import 'user_location_provider.dart';

/// Coverage rectangle the backend reports via `/api/auth/me`. Null until the
/// auth controller has loaded the user (or if the server omits the field).
final supportedBboxProvider = Provider<Bbox?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull?.bbox;
});

/// True when nav-start is allowed.
///
/// Fail-open: if the server hasn't reported a bbox yet, or there is no GPS
/// fix yet, this returns true so the existing "start without fix" path keeps
/// working. Only an actively-outside fix flips the gate to false.
final withinSupportedBboxProvider = Provider<bool>((ref) {
  final bbox = ref.watch(supportedBboxProvider);
  final loc = ref.watch(userLocationProvider);
  if (bbox == null || loc == null) return true;
  return bbox.contains(loc.lat, loc.lng);
});
