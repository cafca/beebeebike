import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../providers/route_provider.dart';
import '../providers/search_history_provider.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';

class RouteCard extends ConsumerWidget {
  const RouteCard({super.key});

  Future<Location> _resolveGps(String label) async {
    try {
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      return Location(
        id: 'gps',
        name: label,
        label: label,
        lng: pos.longitude,
        lat: pos.latitude,
      );
    } catch (_) {
      return Location(
        id: 'gps',
        name: label,
        label: label,
        lng: 13.4533,
        lat: 52.5065,
      );
    }
  }

  Future<void> _openOriginSearch(BuildContext context, WidgetRef ref) async {
    final gpsLabel = AppLocalizations.of(context)!.locationCurrent;
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final origin = result.id == 'gps' ? await _resolveGps(gpsLabel) : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    ref.read(routeControllerProvider.notifier).setOrigin(origin);
  }

  Future<void> _openDestinationSearch(
      BuildContext context, WidgetRef ref) async {
    final gpsLabel = AppLocalizations.of(context)!.locationCurrent;
    final result = await Navigator.of(context).push<Location>(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
    if (result == null || !context.mounted) return;
    final destination =
        result.id == 'gps' ? await _resolveGps(gpsLabel) : result;
    if (!context.mounted) return;
    if (result.id != 'gps') {
      ref.read(searchHistoryProvider.notifier).remember(result);
    }
    if (ref.read(routeControllerProvider).origin == null) {
      final gpsOrigin = await _resolveGps(gpsLabel);
      if (!context.mounted) return;
      ref.read(routeControllerProvider.notifier).setOrigin(gpsOrigin);
    }
    ref.read(routeControllerProvider.notifier).setDestination(destination);
  }

  Future<void> _swap(BuildContext context, WidgetRef ref) async {
    final gpsLabel = AppLocalizations.of(context)!.locationCurrent;
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (destination == null) return;

    final newOrigin = destination;
    final Location newDestination;
    if (origin == null || origin.id == 'gps') {
      newDestination = await _resolveGps(gpsLabel);
    } else {
      newDestination = origin;
    }
    if (!context.mounted) return;
    ref.read(routeControllerProvider.notifier).setOrigin(newOrigin);
    ref.read(routeControllerProvider.notifier).setDestination(newDestination);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final routeState = ref.watch(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;

    final String originLabel;
    if (origin == null || origin.id == 'gps') {
      originLabel = l10n.locationCurrent;
    } else {
      originLabel = origin.name;
    }
    final destLabel = destination?.name;
    final hasDestination = destination != null;

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.person_outline),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: Colors.grey.shade600,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 48, endIndent: 48),
          InkWell(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            onTap: () => _openDestinationSearch(context, ref),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: hasDestination ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destLabel ?? l10n.searchHint,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: hasDestination ? null : Colors.grey,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: hasDestination
                        ? Colors.grey.shade600
                        : Colors.grey.shade300,
                    onPressed:
                        hasDestination ? () => _swap(context, ref) : null,
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
