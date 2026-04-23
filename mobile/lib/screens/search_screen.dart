import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/geocode_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/geocode_result.dart';
import '../models/location.dart';
import '../providers/location_provider.dart';
import '../providers/search_history_provider.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

final _geocodeApiProvider =
    Provider<GeocodeApi>((ref) => GeocodeApi(ref.watch(dioProvider)));

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final List<GeocodeResult> _results = [];
  Timer? _debounce;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _results.clear());
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final results = await ref.read(_geocodeApiProvider).search(query);
      if (mounted) setState(() => _results..clear()..addAll(results));
    } catch (_) {
      if (mounted) setState(() => _results.clear());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectLocation(Location location) {
    Navigator.of(context).pop(location);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final history = ref.watch(searchHistoryProvider);
    final homeLocation = ref.watch(homeLocationProvider).valueOrNull;
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: BbbColors.panel,
      appBar: AppBar(
        leading: const BackButton(color: BbbColors.ink),
        backgroundColor: BbbColors.panel,
        foregroundColor: BbbColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: BbbText.body(),
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            hintStyle: BbbText.body().copyWith(color: BbbColors.inkFaint),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            if (value.trim().isNotEmpty) _search(value.trim());
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader(l10n.searchSectionQuick.toUpperCase()),
          _SearchRow(
            icon: Icons.my_location,
            title: l10n.locationCurrent,
            onTap: () => _selectLocation(Location(
              id: 'gps',
              name: l10n.locationCurrent,
              label: l10n.locationCurrent,
              lng: 0,
              lat: 0,
            )),
          ),
          if (homeLocation != null)
            _SearchRow(
              icon: Icons.home_outlined,
              title: l10n.settingsHome,
              subtitle: homeLocation.label.isNotEmpty
                  ? homeLocation.label
                  : null,
              onTap: () => _selectLocation(homeLocation),
            ),
          const _SectionDivider(),
          if (hasQuery)
            ..._buildResultsSection(l10n)
          else
            ..._buildRecentSection(history),
        ],
      ),
    );
  }

  List<Widget> _buildResultsSection(AppLocalizations l10n) {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    return [
      _SectionHeader(l10n.searchSectionResults.toUpperCase()),
      for (final r in _results)
        _SearchRow(
          icon: Icons.place_outlined,
          title: r.name,
          subtitle: r.label.isNotEmpty ? r.label : null,
          onTap: () => _selectLocation(Location(
            id: r.id,
            name: r.name,
            label: r.label,
            lng: r.lng,
            lat: r.lat,
            street: r.street,
            housenumber: r.housenumber,
          )),
        ),
    ];
  }

  List<Widget> _buildRecentSection(List<Location> history) {
    if (history.isEmpty) return const [];
    final l10n = AppLocalizations.of(context)!;
    return [
      _SectionHeader(l10n.searchSectionRecent.toUpperCase()),
      for (final h in history)
        _SearchRow(
          icon: Icons.history,
          title: h.name,
          subtitle: h.label.isNotEmpty ? h.label : null,
          onTap: () => _selectLocation(h),
        ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Text(label, style: BbbText.eyebrow()),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Divider(height: 1, thickness: 1, color: BbbColors.divider),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: BbbColors.bgAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: BbbColors.inkMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: BbbText.label()),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: BbbText.monoSub(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
