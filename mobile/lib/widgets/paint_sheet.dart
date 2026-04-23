import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/brush_provider.dart';
import '../theme/tokens.dart';

class PaintSheet extends ConsumerWidget {
  const PaintSheet({super.key});

  static const List<int> _values = [-7, -3, -1, 0, 1, 3, 7];

  static const Map<int, Color> _colors = {
    -7: BbbColors.rampHateStrong,
    -3: BbbColors.rampHate,
    -1: BbbColors.rampHateMild,
    0: BbbColors.rampNeutral,
    1: BbbColors.rampLoveMild,
    3: BbbColors.rampLove,
    7: BbbColors.rampLoveStrong,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brushControllerProvider);
    final notifier = ref.read(brushControllerProvider.notifier);
    final mq = MediaQuery.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: BbbColors.panel,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
          boxShadow: BbbShadow.panel,
        ),
        padding: EdgeInsets.fromLTRB(16, 12, 16, mq.padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: BbbColors.grabber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                _PaintToggle(
                  active: state.paintMode,
                  onPressed: notifier.togglePaintMode,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final v in _values)
                        KeyedSubtree(
                          key: ValueKey('paint-chip-$v'),
                          child: _ColorChip(
                            value: v,
                            selected: state.value == v,
                            onTap: () => notifier.setValue(v),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaintToggle extends StatelessWidget {
  const _PaintToggle({required this.active, required this.onPressed});
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = active ? l10n.paintExit : l10n.paintEnter;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        toggled: active,
        label: label,
        child: Material(
          key: const ValueKey('paint-toggle'),
          color: active ? BbbColors.brand : BbbColors.panel,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: active ? BbbColors.brand : BbbColors.divider,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(BbbRadius.ctrl),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(BbbRadius.ctrl),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.brush,
                color: active ? Colors.white : BbbColors.ink,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = PaintSheet._colors[value] ?? BbbColors.rampNeutral;
    final isEraser = value == 0;
    return Semantics(
      button: true,
      selected: selected,
      label: isEraser ? l10n.paintEraser : l10n.paintRatingLabel(value),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isEraser ? BbbColors.panel : color,
            border: Border.all(
              color: selected ? BbbColors.ink : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? const [
                    BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2),
                  ]
                : const [],
          ),
          transformAlignment: Alignment.center,
          transform: selected
              ? Matrix4.diagonal3Values(1.15, 1.15, 1.0)
              : Matrix4.identity(),
          child: isEraser
              ? Icon(Icons.cleaning_services_outlined, size: 20, color: color)
              : null,
        ),
      ),
    );
  }
}
