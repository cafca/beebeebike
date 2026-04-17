import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/turn_banner.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFCFE3D3)),
          const Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: TurnBanner(
                primaryText: 'Turn left onto Kastanienallee',
                distanceText: '200 m',
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12:34 arrival · 10 min'),
                  Row(
                    children: [
                      Icon(Icons.volume_up_outlined),
                      SizedBox(width: 16),
                      Icon(Icons.close),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
