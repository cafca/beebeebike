import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../playback_controller.dart';

class DragPuckOverlay extends ConsumerStatefulWidget {
  const DragPuckOverlay({
    super.key,
    required this.mapController,
  });

  final MapLibreMapController? mapController;

  @override
  ConsumerState<DragPuckOverlay> createState() => _DragPuckOverlayState();
}

class _DragPuckOverlayState extends ConsumerState<DragPuckOverlay> {
  Offset? _screenPos;
  LatLng? _projectedFor;

  Future<void> _project(LatLng latLng) async {
    final c = widget.mapController;
    if (c == null) return;
    final pt = await c.toScreenLocation(latLng);
    if (!mounted) return;
    setState(() {
      _screenPos = Offset(pt.x.toDouble(), pt.y.toDouble());
      _projectedFor = latLng;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playbackControllerProvider);
    final notifier = ref.read(playbackControllerProvider.notifier);
    final override = state.overrideLatLng;
    if (override == null) {
      _screenPos = null;
      _projectedFor = null;
      return const SizedBox.shrink();
    }

    if (_projectedFor != override) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _project(override));
    }
    if (_screenPos == null) return const SizedBox.shrink();
    final pos = _screenPos!;
    return Positioned(
      left: pos.dx - 16,
      top: pos.dy - 16,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) async {
          final c = widget.mapController;
          if (c == null) return;
          final newScreen = pos + d.delta;
          setState(() => _screenPos = newScreen);
          final ll = await c.toLatLng(
            math.Point<double>(newScreen.dx, newScreen.dy),
          );
          notifier.setOverride(ll);
        },
        child: Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFC107),
            border: Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
