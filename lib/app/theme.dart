import 'package:flutter/material.dart';

/// Eine Farbpalette (dunkel oder hell). Gleiche Werte wie Volti und Conti:
/// dunkle Karten mit feinem Rand und vier leuchtende Verläufe.
class Palette {
  const Palette({
    required this.brightness,
    required this.background,
    required this.card,
    required this.cardHigh,
    required this.line,
    required this.muted,
    required this.ink,
    required this.track,
    required this.brand,
    required this.mint,
    required this.sun,
    required this.sky,
    required this.wrong,
  });

  final Brightness brightness;
  final Color background;
  final Color card;

  /// Etwas hellere Fläche auf einer Karte (Knöpfe, Felder).
  final Color cardHigh;
  final Color line;
  final Color muted;
  final Color ink;

  /// Leere Spur eines Balkens.
  final Color track;

  /// Bühne: Pink → Violett. Logo, Hauptknöpfe, Abenteuer, Auswahl.
  final List<Color> brand;

  /// Richtig: Mint → Blau. Richtige Antwort, geschafft, Übungstage.
  final List<Color> mint;

  /// Belohnung: Gelb → Pink. Münzen, Streak, Combo, Sterne, Shop.
  final List<Color> sun;

  /// Zeit und Hinweise: Türkis → Blau. Zeitbalken, Griffbrett, Tipps.
  final List<Color> sky;

  /// Falsche Antwort.
  final Color wrong;

  static const dark = Palette(
    brightness: Brightness.dark,
    background: Color(0xFF0D0E11),
    card: Color(0xFF18191D),
    cardHigh: Color(0xFF202126),
    line: Color(0xFF2A2C32),
    muted: Color(0xFF8E939D),
    ink: Color(0xFFF3F4F6),
    track: Color(0xFF2A2C32),
    brand: [Color(0xFFFF7AC6), Color(0xFF9A6BFF)],
    mint: [Color(0xFF6EF0B5), Color(0xFF4C7CF0)],
    sun: [Color(0xFFFFC83D), Color(0xFFFF6F91)],
    sky: [Color(0xFF5FE3E0), Color(0xFF5B8CFF)],
    wrong: Color(0xFFFF6E7A),
  );

  static const light = Palette(
    brightness: Brightness.light,
    background: Color(0xFFF1F2F6),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFF6F7FA),
    line: Color(0xFFE2E4EA),
    muted: Color(0xFF686D78),
    ink: Color(0xFF16171C),
    track: Color(0xFFECEEF2),
    brand: [Color(0xFFF0479C), Color(0xFF7A3CF0)],
    mint: [Color(0xFF29D398), Color(0xFF3F6FF0)],
    sun: [Color(0xFFFFB400), Color(0xFFFF5A8A)],
    sky: [Color(0xFF34D6E0), Color(0xFF3F6FF0)],
    wrong: Color(0xFFF0506A),
  );
}

/// Die Farben, die gerade gelten (dunkel ist Standard, die Lehrperson kann
/// im Lehrerbereich auf hell oder „wie das Gerät“ stellen). `SuonaApp` setzt
/// die Palette und baut bei einem Wechsel alles neu auf.
class SuonaColors {
  SuonaColors._();

  static Palette _p = Palette.dark;
  static Palette get palette => _p;
  static bool get isDark => _p.brightness == Brightness.dark;

  /// Gibt true zurück, wenn sich etwas geändert hat.
  static bool use(Palette p) {
    if (identical(p, _p)) return false;
    _p = p;
    return true;
  }

  static Color get background => _p.background;
  static Color get card => _p.card;
  static Color get cardHigh => _p.cardHigh;
  static Color get line => _p.line;
  static Color get muted => _p.muted;
  static Color get ink => _p.ink;
  static Color get track => _p.track;
  static Color get wrong => _p.wrong;

  static List<Color> get brand => _p.brand;
  static List<Color> get mint => _p.mint;
  static List<Color> get sun => _p.sun;
  static List<Color> get sky => _p.sky;

  /// Einzelfarben aus den Verläufen (Symbole, Ränder, Text).
  static Color get accent => _p.brand[1];
  static Color get pink => _p.brand[0];
  static Color get ok => _p.mint[0];
  static Color get blue => _p.mint[1];
  static Color get gold => _p.sun[0];
  static Color get rose => _p.sun[1];
  static Color get teal => _p.sky[0];

  /// Schrift und Symbole auf Verläufen: immer weiss (wie bei Volti).
  static const onGradient = Colors.white;

  // Das Notenblatt bleibt in beiden Modi weiss.
  static const paper = Color(0xFFFFFFFF);
  static const paperInk = Color(0xFF16171C);
  static const paperMuted = Color(0xFF686D78);
  static const paperOk = Color(0xFF1F9D6B);
  static const paperWrong = Color(0xFFE0405A);
  static const paperHint = Color(0xFF3F6FF0);
}

/// Verlauf schräg von oben links nach unten rechts.
LinearGradient gradientOf(List<Color> colors, {bool horizontal = false}) => LinearGradient(
  begin: horizontal ? Alignment.centerLeft : Alignment.topLeft,
  end: horizontal ? Alignment.centerRight : Alignment.bottomRight,
  colors: colors,
);

/// Weiches Leuchten unter einem farbigen Knopf.
List<BoxShadow> glowOf(List<Color> colors, {double strength = 0.38, double blur = 26}) => [
  BoxShadow(color: colors.last.withValues(alpha: strength), blurRadius: blur, offset: const Offset(0, 10)),
];

/// Schriften: Sora für Überschriften, Knöpfe und Zahlen, IBM Plex Sans für Text.
const kDisplayFont = 'Sora';
const kBodyFont = 'Plex';

TextStyle display(double size, {Color? color, FontWeight weight = FontWeight.w700, double? height}) => TextStyle(
  fontFamily: kDisplayFont,
  fontSize: size,
  fontWeight: weight,
  color: color ?? SuonaColors.ink,
  height: height ?? 1.15,
  letterSpacing: size >= 24 ? -0.4 : 0,
);

TextStyle body(double size, {Color? color, FontWeight weight = FontWeight.w400, double? height}) => TextStyle(
  fontFamily: kBodyFont,
  fontSize: size,
  fontWeight: weight,
  color: color ?? SuonaColors.ink,
  height: height,
);

ThemeData buildSuonaTheme(Palette p) {
  final dark = p.brightness == Brightness.dark;
  final violet = p.brand[1];
  final scheme = ColorScheme.fromSeed(seedColor: violet, brightness: p.brightness).copyWith(
    primary: violet,
    onPrimary: Colors.white,
    primaryContainer: violet.withValues(alpha: dark ? 0.28 : 0.14),
    onPrimaryContainer: p.ink,
    secondary: p.mint[1],
    onSecondary: Colors.white,
    tertiary: p.sun[0],
    surface: p.card,
    onSurface: p.ink,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.card,
    surfaceContainerLow: p.card,
    surfaceContainer: p.card,
    surfaceContainerHigh: p.cardHigh,
    surfaceContainerHighest: p.cardHigh,
    outline: p.line,
    outlineVariant: p.line,
    error: p.wrong,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kBodyFont, brightness: p.brightness);
  TextStyle h(double s, [FontWeight w = FontWeight.w700]) =>
      TextStyle(fontFamily: kDisplayFont, fontSize: s, fontWeight: w, color: p.ink, height: 1.15);
  final round = RoundedRectangleBorder(borderRadius: BorderRadius.circular(999));
  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    canvasColor: p.background,
    dividerColor: p.line,
    textTheme: base.textTheme
        .apply(bodyColor: p.ink, displayColor: p.ink, fontFamily: kBodyFont)
        .copyWith(
          headlineLarge: h(34),
          headlineMedium: h(28),
          headlineSmall: h(23),
          titleLarge: h(21),
          titleMedium: TextStyle(fontFamily: kBodyFont, fontSize: 17, fontWeight: FontWeight.w600, color: p.ink),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: h(24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: violet,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.cardHigh,
        disabledForegroundColor: p.muted,
        textStyle: h(17),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        shape: round,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.cardHigh,
        side: BorderSide(color: p.line),
        textStyle: TextStyle(fontFamily: kBodyFont, fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: round,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? const Color(0xFFB48CFF) : violet,
        textStyle: TextStyle(fontFamily: kBodyFont, fontSize: 16, fontWeight: FontWeight.w600),
        shape: round,
      ),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: p.line)),
      titleTextStyle: h(22),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(
      color: p.cardHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.cardHigh,
      contentTextStyle: TextStyle(fontFamily: kBodyFont, fontSize: 16, color: p.ink),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.cardHigh,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: violet, width: 2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.cardHigh,
      selectedColor: violet.withValues(alpha: dark ? 0.32 : 0.16),
      side: BorderSide(color: p.line),
      labelStyle: TextStyle(fontFamily: kBodyFont, fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
      shape: round,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.cardHigh,
        foregroundColor: p.ink,
        selectedBackgroundColor: violet,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: p.line),
        textStyle: TextStyle(fontFamily: kBodyFont, fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? violet : p.track),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: violet, thumbColor: violet, inactiveTrackColor: p.track),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: violet, linearTrackColor: p.track),
    listTileTheme: ListTileThemeData(iconColor: p.muted, textColor: p.ink),
    iconTheme: IconThemeData(color: p.ink),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.muted,
      indicatorColor: violet,
      dividerColor: Colors.transparent,
      labelStyle: h(17),
      unselectedLabelStyle: h(17, FontWeight.w600),
    ),
    // Hinweise nur beim Darüberfahren mit der Maus, damit langes Drücken frei bleibt.
    tooltipTheme: const TooltipThemeData(triggerMode: TooltipTriggerMode.manual),
  );
}
