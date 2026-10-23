import 'package:beebeebike/dev/playback_controller.dart';
import 'package:beebeebike/dev/playback_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlaybackDrawer extends ConsumerStatefulWidget {
  const PlaybackDrawer({super.key});

  @override
  ConsumerState<PlaybackDrawer> createState() => _PlaybackDrawerState();
}

class _PlaybackDrawerState extends ConsumerState<PlaybackDrawer> {
  // Direct engine reference — stored in initState so we can safely call
  // engine.pause() from dispose() without touching `ref` (forbidden post-unmount).
  // Initialising here (rather than in build) also closes the race where dispose()
  // could fire before the first build, leaving the Timer.periodic leaked.
  PlaybackEngine? _engine;

  @override
  void initState() {
    super.initState();
    _engine = ProviderScope.containerOf(context, listen: false)
        .read(playbackEngineProvider);
  }

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
              label: '-10m',
              onPressed: hasRoute ? notifier.stepBack : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-forward'),
              icon: Icons.forward_30,
              label: '+10m',
              onPressed: hasRoute ? notifier.stepForward : null,
            ),
            _IconBtn(
              btnKey: const ValueKey('playback-speed'),
              icon: Icons.speed,
              label: '${state.speedMultiplier}x',
              onPressed: hasRoute ? notifier.cycleSpeed : null,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  key: const ValueKey('playback-progress'),
                  value: state.cumulativeM
                      .clamp(0.0, state.routeLengthM.clamp(1.0, double.infinity)),
                  max: state.routeLengthM <= 0 ? 1.0 : state.routeLengthM,
                  onChanged: hasRoute ? notifier.seek : null,
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
