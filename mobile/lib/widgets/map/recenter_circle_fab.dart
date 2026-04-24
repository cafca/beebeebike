import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class RecenterCircleFab extends StatefulWidget {
  const RecenterCircleFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<RecenterCircleFab> createState() => _RecenterCircleFabState();
}

class _RecenterCircleFabState extends State<RecenterCircleFab>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1.0,
  );

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _pressed = false);
    widget.onTap();
    _flash.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Material(
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: BbbColors.panel,
              shape: BoxShape.circle,
              boxShadow: BbbShadow.sm,
            ),
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                final color = Color.lerp(
                  BbbColors.brand,
                  BbbColors.inkMuted,
                  Curves.easeOut.transform(_flash.value),
                )!;
                return Icon(Icons.my_location, color: color, size: 22);
              },
            ),
          ),
        ),
      ),
    );
  }
}
