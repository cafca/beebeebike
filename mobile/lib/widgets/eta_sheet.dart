import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/maneuver_icons.dart';

/// Bottom sheet shown during active navigation. Displays remaining distance,
/// ETA + remaining minutes, a TTS toggle, and a close button that ends the
/// nav session.
class EtaSheet extends StatelessWidget {
  const EtaSheet({
    super.key,
    required this.navState,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.onClose,
  });

  final AsyncValue<NavigationState> navState;
  final bool ttsEnabled;
  final VoidCallback onToggleTts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          navState.when(
            loading: () => const Text('Loading...'),
            error: (_, __) => const Text('—'),
            data: (state) {
              final p = state.progress;
              if (p == null) return const Text('—');
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDistance(p.distanceRemainingM),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    formatEta(p.durationRemainingMs),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              IconButton(
                tooltip: ttsEnabled ? 'Mute voice' : 'Enable voice',
                icon: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off),
                onPressed: onToggleTts,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'End navigation',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
