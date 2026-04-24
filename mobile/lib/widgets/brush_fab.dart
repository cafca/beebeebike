import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/brush_provider.dart';
import '../theme/tokens.dart';
import 'paint_roller_icon.dart';

/// Always-visible paint-mode toggle. Sits at the bottom of the right-side
/// FAB column on every non-navigation view. Flips [BrushController.paintMode].
class BrushFab extends ConsumerWidget {
  const BrushFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = ref.watch(
      brushControllerProvider.select((s) => s.paintMode),
    );
    final label = active ? l10n.paintExit : l10n.paintEnter;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: Material(
          key: const ValueKey('paint-fab'),
          color: active ? BbbColors.ink : BbbColors.panel,
          shape: CircleBorder(
            side: BorderSide(
              color: active ? BbbColors.ink : BbbColors.divider,
              width: 1,
            ),
          ),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () =>
                ref.read(brushControllerProvider.notifier).togglePaintMode(),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: active ? BbbColors.ink : BbbColors.panel,
                shape: BoxShape.circle,
                boxShadow: BbbShadow.sm,
              ),
              child: Center(
                child: PaintRollerIcon(
                  size: 24,
                  color: active ? BbbColors.panel : BbbColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
