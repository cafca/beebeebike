import 'package:flutter/material.dart';

class RecenterFab extends StatelessWidget {
  const RecenterFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'nav-recenter-fab',
      onPressed: onTap,
      child: const Icon(Icons.my_location),
    );
  }
}
