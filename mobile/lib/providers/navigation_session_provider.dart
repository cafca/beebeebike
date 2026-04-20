import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the user is currently in an active navigation session.
///
/// Flipping this flag (instead of pushing a new screen) keeps the single
/// MapLibreMap instance alive across browse ↔ navigate transitions.
final navigationSessionProvider = StateProvider<bool>((ref) => false);
