import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/brush_provider.dart';
import '../theme/tokens.dart';

class UndoRedoFabs extends ConsumerWidget {
  const UndoRedoFabs({super.key, required this.bottomOffset});

  /// Distance from the screen bottom at which the column's bottom edge sits.
  /// Callers match this to the active sheet's top edge so the FABs rise with
  /// the sheet.
  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: l10n.paintUndo,
            child: FloatingActionButton.small(
              key: const ValueKey('undo-fab'),
              heroTag: 'brush-undo-fab',
              onPressed: state.canUndo ? notifier.undo : null,
              backgroundColor:
                  state.canUndo ? BbbColors.panel : BbbColors.bgAlt,
              foregroundColor:
                  state.canUndo ? BbbColors.ink : BbbColors.inkFaint,
              child: const Icon(Icons.undo),
            ),
          ),
          const SizedBox(height: 8),
          Tooltip(
            message: l10n.paintRedo,
            child: FloatingActionButton.small(
              key: const ValueKey('redo-fab'),
              heroTag: 'brush-redo-fab',
              onPressed: state.canRedo ? notifier.redo : null,
              backgroundColor:
                  state.canRedo ? BbbColors.panel : BbbColors.bgAlt,
              foregroundColor:
                  state.canRedo ? BbbColors.ink : BbbColors.inkFaint,
              child: const Icon(Icons.redo),
            ),
          ),
        ],
      ),
    );
  }
}
