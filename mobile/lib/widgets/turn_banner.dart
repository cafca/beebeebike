import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/theme/typography.dart';
import 'package:flutter/material.dart';

class TurnBanner extends StatelessWidget {
  const TurnBanner({
    required this.primaryText, required this.distanceText, super.key,
    this.icon = Icons.straight,
  });

  final String primaryText;
  final String distanceText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: BbbColors.ink,
        borderRadius: BorderRadius.circular(BbbRadius.panel),
        boxShadow: BbbShadow.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 29),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              primaryText,
              style: BbbText.cardTitle()
                  .copyWith(color: Colors.white, fontSize: 20),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            distanceText,
            style: BbbText.monoTime(
              color: Colors.white.withValues(alpha: 0.8),
            ).copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
