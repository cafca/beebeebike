import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/geocode_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/geocode_result.dart';

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final r = _results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(r.name),
                  subtitle: r.label.isNotEmpty ? Text(r.label) : null,
                  onTap: () => Navigator.of(context).pop(r),
                );
              },
            ),
    );
  }
}
