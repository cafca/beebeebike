import 'package:flutter/material.dart';

/// Design tokens for the bicycle-planning "Playful · Light Grey · Comfortable"
/// style. Canonical values; see design_handoff_landing_and_style_guide/README.md.
class BbbColors {
  static const bg = Color(0xFFEEF0F2);
  static const bgAlt = Color(0xFFE6E9ED);
  static const panel = Color(0xFFFFFFFF);
  static const ink = Color(0xFF14272F);
  static const inkMuted = Color(0xFF5B6C76);
  static const inkFaint = Color(0xFF95A3AB);
  static const divider = Color(0xFFEEF2F5);
  static const brand = Color(0xFF19A4C2);
  static const brandSoft = Color(0xFFE0F3F8);
  static const routeInk = Color(0xFF1A2A3E);
  static const accentYellow = Color(0xFFF6B93B);
  static const grabber = Color(0xFFD5DAE0);

  static const rampHateStrong = Color(0xFFB8342E);
  static const rampHate = Color(0xFFD94A4A);
  static const rampHateMild = Color(0xFFEF8379);
  static const rampNeutral = Color(0xFF8A95A1);
  static const rampLoveMild = Color(0xFF7FD9C9);
  static const rampLove = Color(0xFF2EB8A8);
  static const rampLoveStrong = Color(0xFF0E7E72);
}

class BbbRadius {
  static const panel = 22.0;
  static const ctrl = 14.0;
  static const fab = 999.0;
  static const chip = 999.0;
  static const sheetTop = 30.0;
}

class BbbShadow {
  static const panel = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(20, 40, 50, 0.04),
      offset: Offset(0, 2),
      blurRadius: 4,
    ),
    BoxShadow(
      color: Color.fromRGBO(20, 40, 50, 0.12),
      offset: Offset(0, 18),
      blurRadius: 40,
    ),
  ];

  static const sm = <BoxShadow>[
    BoxShadow(
      color: Color.fromRGBO(20, 40, 50, 0.06),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(20, 40, 50, 0.05),
      offset: Offset(0, 4),
      blurRadius: 10,
    ),
  ];
}

class BbbSpacing {
  static const panelTight = 16.0;
  static const panelStd = 20.0;
  static const stackGap = 14.0;
}
