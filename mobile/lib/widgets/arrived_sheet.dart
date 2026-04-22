import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.arrivedTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: Text(l10n.arrivedDone)),
        ],
      ),
    );
  }
}
