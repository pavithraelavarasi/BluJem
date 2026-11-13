import 'package:flutter/material.dart';

/// BluJem's palette: newsprint paper, warm ink, one sunny accent, and the
/// four row colours a BluJem sheet prints its squares in.
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.card,
    required this.sunken,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.rule,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.rows,
    required this.tile,
    required this.tileEdge,
    required this.cursor,
  });

  final Color paper, card, sunken, ink, inkSoft, inkFaint, rule;
  final Color accent, accentSoft, success, successSoft, warning;

  /// Pink, green, blue, yellow — word 1 to 4 — then the Sunday Jumble's purple
  /// and orange for words 5 and 6.
  final List<Color> rows;

  /// The letter tile's face and its pressed-in bottom edge.
  final Color tile, tileEdge;

  /// BluJem blue: the square the next tapped letter goes into.
  final Color cursor;

  Color rowColor(int index) => rows[index % rows.length];

  static const light = Palette(
    paper: Color(0xFFFAF7F0),
    card: Color(0xFFFFFDF8),
    sunken: Color(0xFFF2ECDD),
    ink: Color(0xFF1C1B19),
    inkSoft: Color(0xFF55524B),
    inkFaint: Color(0xFF8A857A),
    rule: Color(0xFFD9D2C3),
    accent: Color(0xFFE8C547),
    accentSoft: Color(0xFFF7EBBF),
    success: Color(0xFF2F6B3A),
    successSoft: Color(0xFFE4EFE2),
    warning: Color(0xFF9A4A17),
    rows: [
      Color(0xFFF6C3D5),
      Color(0xFFC9E6BF),
      Color(0xFFC3DAF2),
      Color(0xFFF7E5A1),
      Color(0xFFE2D3F6),
      Color(0xFFF9D5B4),
    ],
    tile: Color(0xFFFFFFFF),
    tileEdge: Color(0xFFCFC6B3),
    cursor: Color(0xFF1E6FE0),
  );

  static const dark = Palette(
    paper: Color(0xFF161513),
    card: Color(0xFF211F1C),
    sunken: Color(0xFF2B2925),
    ink: Color(0xFFF3EFE6),
    inkSoft: Color(0xFFC2BCAF),
    inkFaint: Color(0xFF8D877B),
    rule: Color(0xFF3A3732),
    accent: Color(0xFFE8C547),
    accentSoft: Color(0xFF4A3F1A),
    success: Color(0xFF7CC48A),
    successSoft: Color(0xFF1F3323),
    warning: Color(0xFFE59A62),
    rows: [
      Color(0xFF8E4A63),
      Color(0xFF4F7A45),
      Color(0xFF4A6C93),
      Color(0xFF8C7A2E),
      Color(0xFF6E5490),
      Color(0xFF9A6236),
    ],
    tile: Color(0xFF34312C),
    tileEdge: Color(0xFF14130F),
    cursor: Color(0xFF7DB0FF),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < 0.5 ? this : (other ?? this);
}

extension PaletteOf on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

const fontFamily = 'Fredoka';

ThemeData buildTheme(Brightness brightness) {
  final p = brightness == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
    surface: p.paper,
    primary: p.ink,
    onPrimary: p.paper,
    secondary: p.accent,
    onSecondary: const Color(0xFF1C1B19),
    error: p.warning,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: p.paper,
    extensions: [p],
  );
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink);
  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.paper,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontFamily: fontFamily),
    ),
    cardTheme: CardThemeData(
      color: p.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.rule),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.ink,
        foregroundColor: p.paper,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: p.rule, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.ink,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.ink, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accentSoft,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 12, color: p.ink),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: p.ink)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.card,
      indicatorColor: p.accentSoft,
      selectedIconTheme: IconThemeData(color: p.ink),
      unselectedIconTheme: IconThemeData(color: p.inkSoft),
      selectedLabelTextStyle: TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, color: p.ink),
      unselectedLabelTextStyle: TextStyle(fontFamily: fontFamily, color: p.inkSoft),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.card, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: p.rule, thickness: 1, space: 1),
  );
}
