import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:beebeebike/widgets/paint_roller_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Always-visible paint-mode toggle. Sits at the bottom of the right-side
/// FAB column on every non-navigation view. Flips `BrushController.paintMode`.
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
            ),
          ),
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
