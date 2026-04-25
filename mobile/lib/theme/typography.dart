import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Type roles per style guide. Manrope for UI, JetBrains Mono for mono sub /
/// stats / eyebrow microcopy. Fraunces is display-only and not used on the
/// landing screen, so it is not wired here.
class BbbText {
  // Screen title — iOS status-bar line.
  static TextStyle screenTitle() => GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: BbbColors.ink,
        height: 1.2,
      );

  // Card title — "Go home", "Work".
  static TextStyle cardTitle() => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: BbbColors.ink,
        height: 1.15,
      );

  // Body — search inputs.
  static TextStyle body() => GoogleFonts.manrope(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: BbbColors.ink,
      );

  // Label — saved item titles.
  static TextStyle label() => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: BbbColors.ink,
      );

  // Mono sub — "Ritterstr. 26 · Kreuzberg".
  static TextStyle monoSub({Color color = BbbColors.inkFaint}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
      );

  // Mono time — "18 min".
  static TextStyle monoTime({Color color = BbbColors.inkMuted}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      );

  // Eyebrow — "SAVED".
  static TextStyle eyebrow() => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: BbbColors.inkFaint,
      );

  // Nav hero — "2 min" in navigation sheet.
  static TextStyle navHero({Color color = BbbColors.inkMuted}) => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        color: color,
        height: 1,
      );
}
