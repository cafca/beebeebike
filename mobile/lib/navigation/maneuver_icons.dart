import 'package:flutter/material.dart';

/// Maps a ferrostar maneuver (type + modifier) to a Material icon.
IconData iconForManeuver(String type, String? modifier) {
  final mod = modifier?.replaceAll('_', ' ');
  if (type == 'turn') {
    if (mod == 'left') return Icons.turn_left;
    if (mod == 'right') return Icons.turn_right;
    if (mod == 'sharp left') return Icons.turn_sharp_left;
    if (mod == 'sharp right') return Icons.turn_sharp_right;
    if (mod == 'slight left') return Icons.turn_slight_left;
    if (mod == 'slight right') return Icons.turn_slight_right;
  }
  if (type == 'arrive') return Icons.flag;
  return Icons.straight;
}

/// Formats a distance in meters as a human-readable string ("150 m", "1.2 km").
String formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

/// Formats an arrival time + minutes remaining ("14:32 arrival · 12 min").
String formatEta(int durationRemainingMs) {
  final eta = DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  final minRemaining = (durationRemainingMs / 60000).round();
  return '$h:$m arrival · $minRemaining min';
}

/// Formats total remaining distance + ETA: "1.4 km · 14:32".
String formatTotalRemaining(double distanceRemainingM, int durationRemainingMs) {
  final dist = formatDistance(distanceRemainingM);
  final eta = DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  return '$dist · $h:$m';
}
