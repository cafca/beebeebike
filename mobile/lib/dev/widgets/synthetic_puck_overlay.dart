import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../playback_controller.dart';

class SyntheticPuckOverlay extends ConsumerStatefulWidget {
  const SyntheticPuckOverlay({super.key, required this.mapController});

  final MapLibreMapController? mapController;

  @override
  ConsumerState<SyntheticPuckOverlay> createState() =>
      _SyntheticPuckOverlayState();
}

class _SyntheticPuckOverlayState extends ConsumerState<SyntheticPuckOverlay> {
  Offset? _screenPos;
  LatLng? _projectedFor;

  Future<void> _project(LatLng ll) async {
    final c = widget.mapController;
    if (c == null) return;
    final pt = await c.toScreenLocation(ll);
    if (!mounted) return;
    setState(() {
      _screenPos = Offset(pt.x.toDouble(), pt.y.toDouble());
      _projectedFor = ll;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    if (state.routeLengthM <= 0) return const SizedBox.shrink();

    final latLng =
        ref.read(playbackControllerProvider.notifier).currentLatLng();

    if (_projectedFor != latLng) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _project(latLng));
    }

    if (_screenPos == null) return const SizedBox.shrink();

    return Positioned(
      left: _screenPos!.dx - 11,
      top: _screenPos!.dy - 11,
      child: IgnorePointer(
        child: Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF1E88E5),
            border: Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
