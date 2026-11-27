import 'package:flutter/material.dart';

/// BluJem's palette, "Jewel night": deep navy, gold and gem blue, cream
/// letter tiles with navy letters, and bright gem colours for solved rows.
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
    required this.tileInk,
    required this.cursor,
  });

  final Color paper, card, sunken, ink, inkSoft, inkFaint, rule;
  final Color accent, accentSoft, success, successSoft, warning;

  /// Pink, green, blue, yellow — word 1 to 4 — then the Sunday BluJem's purple
  /// and orange for words 5 and 6.
  final List<Color> rows;

  /// The letter tile's face, its pressed-in bottom edge, and its letters.
  final Color tile, tileEdge, tileInk;

  /// BluJem blue: the square the next tapped letter goes into.
  final Color cursor;

  Color rowColor(int index) => rows[index % rows.length];

  static const jewel = Palette(
    paper: Color(0xFF14204A),
    card: Color(0xFF1F3170),
    sunken: Color(0xFF101A3D),
    ink: Color(0xFFFFFFFF),
    inkSoft: Color(0xFFC3D0F2),
    inkFaint: Color(0xFF8D9BC9),
    rule: Color(0xFF34498C),
    accent: Color(0xFFFFD23F),
    accentSoft: Color(0xFF2E3F96),
    success: Color(0xFF5BE38B),
    successSoft: Color(0xFF1B4A3E),
    warning: Color(0xFFFF8A3D),
    rows: [
      Color(0xFFFF8FC4),
      Color(0xFF6FE6A0),
      Color(0xFF6CCBFF),
      Color(0xFFFFD84D),
      Color(0xFFC3A8FF),
      Color(0xFFFFAF66),
    ],
    tile: Color(0xFFFFF6DC),
    tileEdge: Color(0xFFC9A94A),
    tileInk: Color(0xFF14204A),
    cursor: Color(0xFF1E8CFF),
  );

  /// One look in every light: the app is always Jewel night.
  static const light = jewel, dark = jewel;

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
  const p = Palette.jewel;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: Brightness.dark,
    surface: p.paper,
    primary: p.ink,
    onPrimary: p.paper,
    secondary: p.accent,
    onSecondary: p.tileInk,
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
        side: BorderSide(color: p.rule, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.tileInk,
        disabledBackgroundColor: p.rule,
        disabledForegroundColor: p.inkFaint,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        // A game button: a darker gold edge under the face.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFC99A00), width: 2),
        ),
        elevation: 0,
        textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 16),
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
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.card,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.accent,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w600, fontSize: 12, color: p.ink),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? p.tileInk : p.ink),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: p.card,
      indicatorColor: p.accent,
      selectedIconTheme: IconThemeData(color: p.tileInk),
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
      backgroundColor: p.card,
      contentTextStyle: TextStyle(fontFamily: fontFamily, color: p.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: p.rule, thickness: 1, space: 1),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.card),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.tileInk : p.ink),
        side: WidgetStatePropertyAll(BorderSide(color: p.rule, width: 1.5)),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700)),
      ),
    ),
  );
}
