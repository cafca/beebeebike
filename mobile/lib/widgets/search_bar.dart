import 'package:flutter/material.dart';

class BeeBeeBikeSearchBar extends StatelessWidget {
  const BeeBeeBikeSearchBar({
    super.key,
    required this.onTap,
    required this.onAvatarTap,
  });

  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: onTap,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Text('Search here...'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              child: IconButton(
                onPressed: onAvatarTap,
                icon: const Icon(Icons.person_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
