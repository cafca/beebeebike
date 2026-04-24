import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home_sheet.dart';
import 'compass_fab_inline.dart';
import 'recenter_circle_fab.dart';

/// Home-mode bottom UI: the draggable [HomeSheet] plus a recenter/compass
/// FAB column whose vertical position tracks the sheet's current snap size.
class HomeSheetContainer extends ConsumerStatefulWidget {
  const HomeSheetContainer({
    super.key,
    required this.onFlyToMyLocation,
    required this.onResetBearing,
    required this.onNavigateHome,
  });

  final VoidCallback onFlyToMyLocation;
  final VoidCallback onResetBearing;
  final VoidCallback onNavigateHome;

  @override
  ConsumerState<HomeSheetContainer> createState() => _HomeSheetContainerState();
}

class _HomeSheetContainerState extends ConsumerState<HomeSheetContainer> {
  final _sheetController = DraggableScrollableController();

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _sheetController,
          builder: (context, _) {
            final size =
                _sheetController.isAttached ? _sheetController.size : 0.16;
            final sheetPx = size * mq.size.height;
            return Positioned(
              right: 16,
              bottom: sheetPx + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CompassFabInline(onResetBearing: widget.onResetBearing),
                  RecenterCircleFab(onTap: widget.onFlyToMyLocation),
                ],
              ),
            );
          },
        ),
        HomeSheet(
          onNavigateHome: widget.onNavigateHome,
          sheetController: _sheetController,
        ),
      ],
    );
  }
}
