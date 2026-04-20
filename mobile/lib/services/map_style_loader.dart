import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../app.dart';

const _styleAssetPath = 'assets/styles/beebeebike-style.json';

/// Loads the bundled style, substitutes the tile-server base URL, and writes
/// the result to the app's temp directory. Returns the absolute file path.
///
/// We write to disk because `maplibre_gl` 0.20.0's iOS plugin silently drops
/// inline JSON passed to `styleString` (see `MapLibreMapController.swift`'s
/// `setStyleString`, which logs "JSON style currently not supported" and
/// no-ops). Newer 0.25+ supports it but conflicts with ferrostar_flutter's
/// `maplibre-gl-native-distribution` version range.
Future<String> loadMapStyle(String tileServerBaseUrl) async {
  final raw = await rootBundle.loadString(_styleAssetPath);
  final resolved = raw.replaceAll('{{TILE_BASE}}', tileServerBaseUrl);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/beebeebike-style.json');
  await file.writeAsString(resolved, flush: true);
  return file.path;
}

final mapStyleProvider = FutureProvider<String>((ref) {
  final config = ref.watch(appConfigProvider);
  return loadMapStyle(config.tileServerBaseUrl);
});
