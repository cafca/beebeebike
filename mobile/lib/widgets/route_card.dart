import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/location.dart';
import '../providers/route_provider.dart';
import '../providers/search_history_provider.dart';
import '../screens/search_screen.dart';

class RouteCard extends ConsumerWidget {
  const RouteCard({super.key});

  Future<Location> _resolveGps() async {
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      return Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lng: pos.longitude,
        lat: pos.latitude,
      );
    } catch (_) {
      return const Location(
        id: 'gps',
        name: 'Mein Standort',
        label: 'Mein Standort',
        lng: 13.4533,
        lat: 52.5065,
      );
    }
  }

  Future<void> _openOriginSearch(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final origin = result.id == 'gps' ? await _resolveGps() : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    ref.read(routeControllerProvider.notifier).setOrigin(origin);
  }

  Future<void> _openDestinationSearch(
      BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final destination = result.id == 'gps' ? await _resolveGps() : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    if (ref.read(routeControllerProvider).origin == null) {
      final gpsOrigin = await _resolveGps();
      if (!context.mounted) return;
      ref.read(routeControllerProvider.notifier).setOrigin(gpsOrigin);
    }
    ref.read(routeControllerProvider.notifier).setDestination(destination);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = ref.watch(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;

    final String originLabel;
    if (origin == null || origin.id == 'gps') {
      originLabel = 'Mein Standort';
    } else {
      originLabel = origin.name;
    }
    final destLabel = destination?.name;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => _openOriginSearch(context, ref),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.my_location, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      originLabel,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48),
          InkWell(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => _openDestinationSearch(context, ref),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: destLabel != null ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destLabel ?? 'Wohin?',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: destLabel != null ? null : Colors.grey,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
