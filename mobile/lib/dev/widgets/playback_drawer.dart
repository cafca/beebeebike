import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playback_controller.dart';
import '../playback_engine.dart';

class PlaybackDrawer extends ConsumerStatefulWidget {
  const PlaybackDrawer({super.key});

  @override
  ConsumerState<PlaybackDrawer> createState() => _PlaybackDrawerState();
}

class _PlaybackDrawerState extends ConsumerState<PlaybackDrawer> {
  // Direct engine reference — stored during build so we can safely call
  // engine.pause() from dispose() without touching `ref` (forbidden post-unmount).
  PlaybackEngine? _engine;

  @override
  void dispose() {
    // Stop the engine's periodic timer before the widget is fully unmounted.
    // This prevents a fakeAsync "pending timer" invariant failure in tests and
    // avoids unnecessary ticks after the overlay is removed in production.
    _engine?.pause();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _engine = ref.read(playbackEngineProvider);
    final state = ref.watch(playbackControllerProvider);
    final notifier = ref.read(playbackControllerProvider.notifier);
    final hasRoute = state.routeLengthM > 0;

    return Container(
      width: 64,
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconBtn(
              btnKey: const ValueKey('playback-play'),
              icon: state.isPlaying ? Icons.pause : Icons.play_arrow,
              label: state.isPlaying ? 'pause' : 'play',
              onPressed: !hasRoute
                  ? null
                  : () => state.isPlaying ? notifier.pause() : notifier.play(),
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-restart'),
              icon: Icons.skip_previous,
              label: 'restart',
              onPressed: hasRoute ? notifier.restart : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-back'),
              icon: Icons.replay,
              label: '-100m',
              onPressed: hasRoute ? notifier.stepBack : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-forward'),
              icon: Icons.forward_30,
              label: '+100m',
              onPressed: hasRoute ? notifier.stepForward : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-speed'),
              icon: Icons.speed,
              label: '${state.speedMultiplier}x',
              onPressed: hasRoute ? notifier.cycleSpeed : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-drag'),
              icon: Icons.open_with,
              label: state.overrideLatLng != null ? 'on' : 'off',
              onPressed: !hasRoute
                  ? null
                  : () {
                      if (state.overrideLatLng != null) {
                        notifier.clearOverride();
                      } else {
                        // Seed override at current sim latlng so the puck is
                        // grabbable immediately; the operator then drags it.
                        notifier.setOverride(notifier.currentLatLng());
                      }
                    },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  key: const ValueKey('playback-progress'),
                  value: state.cumulativeM
                      .clamp(0.0, state.routeLengthM.clamp(1.0, double.infinity)),
                  min: 0.0,
                  max: state.routeLengthM <= 0 ? 1.0 : state.routeLengthM,
                  onChanged: hasRoute ? (v) => notifier.seek(v) : null,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                hasRoute
                    ? '${state.cumulativeM.round()} / ${state.routeLengthM.round()} m'
                    : '— / —',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.btnKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key btnKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null ? Colors.white38 : Colors.white;
    return SizedBox(
      height: 64,
      child: IconButton(
        key: btnKey,
        iconSize: 36,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        icon: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 9),
              overflow: TextOverflow.clip,
            ),
          ],
        ),
        onPressed: onPressed,
      ),
    );
  }
}
