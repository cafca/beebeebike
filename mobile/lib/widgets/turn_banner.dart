import 'package:flutter/material.dart';

class TurnBanner extends StatelessWidget {
  const TurnBanner({
    super.key,
    required this.primaryText,
    required this.distanceText,
  });

  final String primaryText;
  final String distanceText;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F8F56),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.turn_left, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              primaryText,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Text(distanceText, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
