import 'package:flutter/material.dart';

/// Farben von Suona. Die Spielbildschirme sind eine Bühne (dunkles Blau mit
/// Scheinwerferlicht), der Lehrerbereich ist hell und ruhig.
class SuonaColors {
  SuonaColors._();

  // Bühne
  static const stage = Color(0xFF1B1A3A);
  static const stageDeep = Color(0xFF110F28);
  static const stageFloor = Color(0xFF2C2A55);
  static const stageLine = Color(0xFF3E3C70);
  static const onStage = Color(0xFFF4F2FF);
  static const onStageMuted = Color(0xFFA9A6D0);

  // Akzente
  static const spot = Color(0xFFFFC233); // Bühnenlicht, Münzen
  static const spotDeep = Color(0xFFC8901A);
  static const red = Color(0xFFD63A4A); // Verstärker-Rot
  static const coral = Color(0xFFFF6B78);
  static const teal = Color(0xFF23A89C);
  static const violet = Color(0xFF7C5CD6);

  // Rückmeldung
  static const ok = Color(0xFF2FB36F);
  static const okDeep = Color(0xFF1F8A54);
  static const wrong = Color(0xFFE5484D);

  // Papier (Notenblatt) und Schrift
  static const paper = Color(0xFFFFFDF8);
  static const ink = Color(0xFF1D1B36);
  static const inkMuted = Color(0xFF5A5E7A);
  static const light = Color(0xFFF3F4FA);
  static const line = Color(0xFFDADDEB);
}

/// Schriften: Baloo für Überschriften und Knöpfe, Atkinson Hyperlegible für Text.
const kDisplayFont = 'Baloo';
const kBodyFont = 'Atkinson';

TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w800, double? height}) =>
    TextStyle(fontFamily: kDisplayFont, fontSize: size, fontWeight: weight, color: color, height: height ?? 1.1);

ThemeData buildSuonaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SuonaColors.red,
    primary: SuonaColors.red,
    secondary: SuonaColors.teal,
    tertiary: SuonaColors.spot,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kBodyFont);
  return base.copyWith(
    scaffoldBackgroundColor: SuonaColors.light,
    textTheme: base.textTheme.copyWith(
      headlineLarge: display(34, color: SuonaColors.ink),
      headlineMedium: display(28, color: SuonaColors.ink),
      headlineSmall: display(23, color: SuonaColors.ink, weight: FontWeight.w700),
      titleLarge: display(21, color: SuonaColors.ink, weight: FontWeight.w700),
      titleMedium: base.textTheme.titleMedium!.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: SuonaColors.light,
      foregroundColor: SuonaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: display(24, color: SuonaColors.ink, weight: FontWeight.w700),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: display(18, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        textStyle: display(17, weight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: SuonaColors.line),
      ),
    ),
    // Hinweise nur beim Darüberfahren mit der Maus, damit langes Drücken frei bleibt.
    tooltipTheme: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
  );
}
