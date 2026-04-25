import 'package:beebeebike/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildBbbTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: BbbColors.brand,
      primary: BbbColors.brand,
      surface: BbbColors.panel,
      onSurface: BbbColors.ink,
    ),
    scaffoldBackgroundColor: BbbColors.bg,
    useMaterial3: true,
  );

  final textTheme = GoogleFonts.manropeTextTheme(base.textTheme).apply(
    bodyColor: BbbColors.ink,
    displayColor: BbbColors.ink,
  );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: BbbColors.divider,
    dividerTheme: const DividerThemeData(
      color: BbbColors.divider,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: BbbColors.panel,
      foregroundColor: BbbColors.ink,
      surfaceTintColor: BbbColors.panel,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.manrope(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: BbbColors.ink,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: BbbColors.inkMuted,
      textColor: BbbColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        borderSide: const BorderSide(color: BbbColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        borderSide: const BorderSide(color: BbbColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        borderSide: const BorderSide(color: BbbColors.brand, width: 1.5),
      ),
      labelStyle: GoogleFonts.manrope(color: BbbColors.inkMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BbbColors.ink,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BbbRadius.ctrl),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        textStyle: GoogleFonts.manrope(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
