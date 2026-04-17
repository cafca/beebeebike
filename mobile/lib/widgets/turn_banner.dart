import 'package:flutter/material.dart';

class TurnBanner extends StatelessWidget {
  const TurnBanner({
    super.key,
    required this.primaryText,
    required this.distanceText,
    this.icon = Icons.straight,
  });

  final String primaryText;
  final String distanceText;
  final IconData icon;

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
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              primaryText,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          Text(distanceText, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
