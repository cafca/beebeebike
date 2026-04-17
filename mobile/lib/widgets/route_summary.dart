import 'package:flutter/material.dart';

class RouteSummary extends StatelessWidget {
  const RouteSummary({
    super.key,
    required this.durationMinutes,
    required this.distanceKm,
    required this.onStart,
  });

  final int durationMinutes;
  final double distanceKm;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🚲 $durationMinutes min · ${distanceKm.toStringAsFixed(1)} km'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onStart,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
