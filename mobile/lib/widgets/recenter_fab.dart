import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Aqua-brand recenter FAB — 52×52 circle, white crosshair icon. Used when
/// the navigation camera has been panned off the user.
class RecenterFab extends StatelessWidget {
  const RecenterFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BbbColors.brand,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: BbbShadow.sm,
          ),
          child: const Icon(Icons.my_location, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
