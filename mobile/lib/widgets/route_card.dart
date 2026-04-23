import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/location.dart';
import '../providers/route_provider.dart';
import '../providers/search_history_provider.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: BbbColors.panel,
        borderRadius: BorderRadius.circular(20),
        boxShadow: BbbShadow.panel,
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SearchRow(
            leading: const Icon(
              Icons.my_location,
              size: 18,
              color: BbbColors.brand,
            ),
            value: originLabel,
            valueColor: BbbColors.ink,
            valueWeight: FontWeight.w600,
            trailing: _GhostIconButton(
              icon: Icons.person_outline,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            onTap: () => _openOriginSearch(context, ref),
          ),
          const Divider(height: 1, color: BbbColors.divider),
          _SearchRow(
            leading: const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: BbbColors.inkFaint,
            ),
            value: destLabel ?? l10n.searchHint,
            valueColor: hasDestination ? BbbColors.ink : BbbColors.inkFaint,
            valueWeight: FontWeight.w500,
            trailing: _GhostIconButton(
              icon: Icons.swap_vert,
              enabled: hasDestination,
              onTap: hasDestination ? () => _swap(context, ref) : null,
            ),
            onTap: () => _openDestinationSearch(context, ref),
          ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.leading,
    required this.value,
    required this.valueColor,
    required this.valueWeight,
    required this.trailing,
    required this.onTap,
  });

  final Widget leading;
  final String value;
  final Color valueColor;
  final FontWeight valueWeight;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 22, height: 22, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                style: BbbText.body()
                    .copyWith(color: valueColor, fontWeight: valueWeight),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: enabled ? BbbColors.inkMuted : BbbColors.inkFaint,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
