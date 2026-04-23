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
      appBar: AppBar(
        leading: const BackButton(),
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: (value) {
            _debounce?.cancel();
            if (value.trim().isNotEmpty) _search(value.trim());
          },
        ),
      ),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.my_location),
            title: Text(l10n.locationCurrent),
            onTap: () => _selectLocation(Location(
              id: 'gps',
              name: l10n.locationCurrent,
              label: l10n.locationCurrent,
              lng: 0,
              lat: 0,
            )),
          ),
          if (homeLocation != null)
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(l10n.settingsHome),
              subtitle: homeLocation.label.isNotEmpty
                  ? Text(homeLocation.label)
                  : null,
              onTap: () => _selectLocation(homeLocation),
            ),
          const Divider(height: 1),
          Expanded(
            child: hasQuery
                ? _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(r.name),
                            subtitle:
                                r.label.isNotEmpty ? Text(r.label) : null,
                            onTap: () => _selectLocation(Location(
                              id: r.id,
                              name: r.name,
                              label: r.label,
                              lng: r.lng,
                              lat: r.lat,
                            )),
                          );
                        },
                      )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final h = history[index];
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(h.name),
                        subtitle: h.label.isNotEmpty ? Text(h.label) : null,
                        onTap: () => _selectLocation(h),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
