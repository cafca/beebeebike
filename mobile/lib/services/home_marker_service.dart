import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/location.dart';

/// Owns the home-location Symbol on the MapLibre map. Re-renders the marker
/// image and places a single [Symbol] at [Location], or removes it when home
/// is null.
class HomeMarkerService {
  Symbol? _marker;
  bool _imageLoaded = false;

  Future<void> update(
      MapLibreMapController controller, Location? home) async {
    final existing = _marker;
    if (existing != null) {
      await controller.removeSymbol(existing);
      _marker = null;
    }
    if (home == null) return;
    if (!_imageLoaded) {
      await controller.addImage('home-marker', await _createImage());
      _imageLoaded = true;
    }
    _marker = await controller.addSymbol(SymbolOptions(
      geometry: LatLng(home.lat, home.lng),
      iconImage: 'home-marker',
      iconSize: 1.0,
      iconAnchor: 'center',
    ));
  }

  static Future<Uint8List> _createImage() async {
    const double size = 52;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = const Color(0xFF3B82F6),
    );
    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(Icons.home.codePoint),
        style: TextStyle(
          fontSize: size * 0.72,
          fontFamily: Icons.home.fontFamily,
          package: Icons.home.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}
