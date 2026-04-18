import 'package:flutter/material.dart';

class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arrived', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
