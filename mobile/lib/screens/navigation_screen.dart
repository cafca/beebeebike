import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/navigation_service.dart';
import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../widgets/turn_banner.dart';

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late final NavigationService _navigationService;

  @override
  void initState() {
    super.initState();
    _navigationService = ref.read(navigationServiceProvider);
    _startNavigation();
  }

  @override
  void dispose() {
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (origin == null || destination == null) return;

    try {
      await _navigationService.start(
            origin: WaypointInput(lat: origin.lat, lng: origin.lng),
            destination:
                WaypointInput(lat: destination.lat, lng: destination.lng),
          );
    } catch (e, st) {
      debugPrint('NavigationScreen: failed to start navigation: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);

    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFCFE3D3)),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: navState.when(
                loading: () => const TurnBanner(
                  primaryText: 'Starting navigation...',
                  distanceText: '',
                ),
                error: (e, _) => const TurnBanner(
                  primaryText: 'Navigation error',
                  distanceText: '',
                  icon: Icons.error_outline,
                ),
                data: (state) => TurnBanner(
                  primaryText: state.currentVisual?.primaryText ?? 'On route',
                  distanceText: state.progress != null
                      ? _formatDistance(
                          state.progress!.distanceToNextManeuverM)
                      : '',
                  icon: state.currentVisual != null
                      ? _iconForManeuver(
                          state.currentVisual!.maneuverType,
                          state.currentVisual!.maneuverModifier,
                        )
                      : Icons.straight,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    navState.when(
                      loading: () => const Text('Loading...'),
                      error: (_, __) => const Text('—'),
                      data: (state) {
                        final p = state.progress;
                        if (p == null) return const Text('—');
                        return Text(_formatEta(p.durationRemainingMs));
                      },
                    ),
                    Row(
                      children: [
                        const Icon(Icons.volume_up_outlined),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForManeuver(String type, String? modifier) {
  if (type == 'turn') {
    if (modifier == 'left') return Icons.turn_left;
    if (modifier == 'right') return Icons.turn_right;
    if (modifier == 'sharp left') return Icons.turn_sharp_left;
    if (modifier == 'sharp right') return Icons.turn_sharp_right;
    if (modifier == 'slight left') return Icons.turn_slight_left;
    if (modifier == 'slight right') return Icons.turn_slight_right;
  }
  if (type == 'arrive') return Icons.flag;
  return Icons.straight;
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatEta(int durationRemainingMs) {
  final eta =
      DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  final minRemaining = (durationRemainingMs / 60000).round();
  return '$h:$m arrival · $minRemaining min';
}
