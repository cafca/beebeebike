import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({required this.current, required this.total, super.key});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: i == current ? 20 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == current ? BbbColors.brand : BbbColors.inkFaint,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
      ],
    );
  }
}
