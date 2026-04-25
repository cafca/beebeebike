import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/brush_provider.dart';
import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: BbbColors.ink,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BbbRadius.sheetTop)),
        boxShadow: BbbShadow.panel,
      ),
      padding: EdgeInsets.fromLTRB(16, 20, 16, mq.padding.bottom + 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _values.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            KeyedSubtree(
              key: ValueKey('paint-chip-${_values[i]}'),
              child: _ColorChip(
                value: _values[i],
                selected: state.value == _values[i],
                onTap: () => notifier.setValue(_values[i]),
              ),
            ),
          ],
        ],
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
              color: selected ? BbbColors.panel : Colors.transparent,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          transformAlignment: Alignment.center,
          transform: selected
              ? Matrix4.diagonal3Values(1.15, 1.15, 1)
              : Matrix4.identity(),
          child: isEraser
              ? Icon(Icons.cleaning_services_outlined, size: 20, color: color)
              : null,
        ),
      ),
    );
  }
}
