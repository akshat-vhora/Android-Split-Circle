import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Core Colors ──────────────────────────────────────────────
  static const _primary = Color(0xFF126CDE);
  static const _primaryLight = Color(0xFF40A0F6);

  static const _secondary = Color(0xFF0BADBC);
  static const _secondaryLight = Color(0xFF32E3CF);
  static const _tertiary = Color(0xFFFFD166);
  static const _error = Color(0xFFEF4444);
  static const _success = Color(0xFF34D399);

  // Dark surfaces
  static const _bgDark = Color(0xFF0B0B14);
  static const _surfaceDark = Color(0xFF12121E);
  static const _surfaceVariantDark = Color(0xFF1C1C2E);
  static const _surfaceContainerDark = Color(0xFF16162A);

  // Light surfaces
  static const _bgLight = Color(0xFFF5F5FA);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _surfaceVariantLight = Color(0xFFEEEEF4);

  // Text
  static const _textPrimaryDark = Color(0xFFF1F1F6);
  static const _textSecondaryDark = Color(0xFF9E9EB8);
  static const _textPrimaryLight = Color(0xFF1A1A2E);
  static const _textSecondaryLight = Color(0xFF6B6B80);
}

// ── Neo-Fintech Dark Theme ────────────────────────────────────
ThemeData buildDarkTheme() {
  final colorScheme = ColorScheme.dark(
    primary: AppTheme._primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF2B1B5E),
    onPrimaryContainer: const Color(0xFFE8DEFF),
    secondary: AppTheme._secondary,
    onSecondary: const Color(0xFF00331E),
    secondaryContainer: const Color(0xFF064E3B),
    onSecondaryContainer: const Color(0xFFA7F3D0),
    tertiary: AppTheme._tertiary,
    onTertiary: const Color(0xFF3B2E00),
    error: AppTheme._error,
    onError: Colors.white,
    errorContainer: const Color(0xFF4A0E0E),
    surface: AppTheme._surfaceDark,
    onSurface: AppTheme._textPrimaryDark,
    surfaceContainerHighest: AppTheme._surfaceVariantDark,
    onSurfaceVariant: AppTheme._textSecondaryDark,
    outline: const Color(0xFF2E2E42),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppTheme._bgDark,

    // ── Typography ──────────────────────────────────────────────
    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppTheme._textPrimaryDark,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppTheme._textPrimaryDark,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme._textPrimaryDark,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._textPrimaryDark,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme._textSecondaryDark,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme._textPrimaryDark,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryDark,
        letterSpacing: 0.2,
      ),
    ),

    // ── Splash / Ink ────────────────────────────────────────────
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,

    // ── AppBar ──────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppTheme._textPrimaryDark,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryDark,
      ),
    ),

    // ── Card ────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppTheme._surfaceContainerDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
    ),

    // ── Elevated Button ─────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme._primary,
        foregroundColor: Colors.white,
        overlayColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppTheme._primary.withValues(alpha: 0.3),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    // ── Outlined Button ─────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme._primary,
        overlayColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 54),
        side: BorderSide(color: AppTheme._primary.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // ── Text Button ─────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme._primary,
        overlayColor: Colors.transparent,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // ── Icon Button ─────────────────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(overlayColor: Colors.transparent),
    ),

    // ── Filled Button ───────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(overlayColor: Colors.transparent),
    ),

    // ── Input Decoration ────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTheme._surfaceVariantDark,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._textSecondaryDark,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryDark,
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme._error,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: const Color(0xFF2E2E42)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),

    // ── Navigation Bar ──────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppTheme._surfaceContainerDark.withValues(alpha: 0.85),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppTheme._primary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme._primary,
          );
        }
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme._textSecondaryDark,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppTheme._primary, size: 22);
        }
        return const IconThemeData(
          color: AppTheme._textSecondaryDark,
          size: 22,
        );
      }),
      elevation: 0,
      height: 68,
    ),

    // ── Navigation Drawer ───────────────────────────────────────
    drawerTheme: DrawerThemeData(
      backgroundColor: AppTheme._surfaceDark,
      shape: const RoundedRectangleBorder(),
    ),

    // ── Floating Action Button ──────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppTheme._primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    // ── Bottom Sheet ────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppTheme._surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
    ),

    // ── Dialog ──────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppTheme._surfaceDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),

    // ── Chip ────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppTheme._surfaceVariantDark,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme._textPrimaryDark,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      elevation: 0,
      brightness: Brightness.dark,
    ),

    // ── Snackbar ────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTheme._surfaceVariantDark,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._textPrimaryDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    // ── Divider ─────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: const Color(0xFF2E2E42),
      thickness: 0.5,
      space: 1,
    ),

    // ── Popup Menu ──────────────────────────────────────────────
    popupMenuTheme: PopupMenuThemeData(
      color: AppTheme._surfaceVariantDark,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
    ),

    // ── Extensions ──────────────────────────────────────────────
    extensions: const [
      AppColors(
        success: AppTheme._success,
        tertiary: AppTheme._tertiary,
        surfaceVariant: AppTheme._surfaceVariantDark,
        surfaceContainer: AppTheme._surfaceContainerDark,
        primaryLight: AppTheme._primaryLight,
        secondaryLight: AppTheme._secondaryLight,
      ),
    ],
  );
}

// ── Neo-Fintech Light Theme ───────────────────────────────────
ThemeData buildLightTheme() {
  final colorScheme = ColorScheme.light(
    primary: AppTheme._primary,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFEDE9FE),
    onPrimaryContainer: const Color(0xFF2D1B69),
    secondary: const Color(0xFF00B894),
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFD1FAE5),
    onSecondaryContainer: const Color(0xFF064E3B),
    tertiary: AppTheme._tertiary,
    onTertiary: const Color(0xFF3B2E00),
    error: AppTheme._error,
    onError: Colors.white,
    errorContainer: const Color(0xFFFEE2E2),
    surface: AppTheme._surfaceLight,
    onSurface: AppTheme._textPrimaryLight,
    surfaceContainerHighest: AppTheme._surfaceVariantLight,
    onSurfaceVariant: AppTheme._textSecondaryLight,
    outline: const Color(0xFFD4D4E0),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppTheme._bgLight,

    textTheme: GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppTheme._textPrimaryLight,
        letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppTheme._textPrimaryLight,
        letterSpacing: -0.3,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppTheme._textPrimaryLight,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._textPrimaryLight,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme._textSecondaryLight,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
        letterSpacing: 0.5,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme._textPrimaryLight,
        letterSpacing: 0.3,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryLight,
        letterSpacing: 0.2,
      ),
    ),

    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    focusColor: Colors.transparent,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppTheme._textPrimaryLight,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppTheme._textPrimaryLight,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: AppTheme._surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme._primary,
        foregroundColor: Colors.white,
        overlayColor: Colors.transparent,
        elevation: 0,
        shadowColor: AppTheme._primary.withValues(alpha: 0.2),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme._primary,
        overlayColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 54),
        side: const BorderSide(color: AppTheme._primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppTheme._primary,
        overlayColor: Colors.transparent,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(overlayColor: Colors.transparent),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(overlayColor: Colors.transparent),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppTheme._surfaceVariantLight,
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._textSecondaryLight,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryLight,
      ),
      errorStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppTheme._error,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: const Color(0xFFD4D4E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme._error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppTheme._surfaceLight.withValues(alpha: 0.9),
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppTheme._primary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme._primary,
          );
        }
        return GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppTheme._textSecondaryLight,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppTheme._primary, size: 22);
        }
        return const IconThemeData(
          color: AppTheme._textSecondaryLight,
          size: 22,
        );
      }),
      elevation: 0,
      height: 68,
    ),

    drawerTheme: DrawerThemeData(
      backgroundColor: AppTheme._surfaceLight,
      shape: const RoundedRectangleBorder(),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppTheme._primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppTheme._surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 0,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppTheme._surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppTheme._surfaceVariantLight,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme._textPrimaryLight,
      ),
      secondaryLabelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme._textSecondaryLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      elevation: 0,
      brightness: Brightness.light,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppTheme._textPrimaryLight,
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme._surfaceLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    dividerTheme: DividerThemeData(
      color: const Color(0xFFE5E5F0),
      thickness: 0.5,
      space: 1,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppTheme._surfaceLight,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 4,
    ),

    extensions: const [
      AppColors(
        success: AppTheme._success,
        tertiary: AppTheme._tertiary,
        surfaceVariant: Color(0xFFEEEEF4),
        surfaceContainer: AppTheme._surfaceLight,
        primaryLight: AppTheme._primaryLight,
        secondaryLight: AppTheme._secondaryLight,
      ),
    ],
  );
}

// ── Theme Extension ───────────────────────────────────────────
class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color tertiary;
  final Color surfaceVariant;
  final Color surfaceContainer;
  final Color primaryLight;
  final Color secondaryLight;

  const AppColors({
    required this.success,
    required this.tertiary,
    required this.surfaceVariant,
    required this.surfaceContainer,
    required this.primaryLight,
    required this.secondaryLight,
  });

  @override
  AppColors copyWith({
    Color? success,
    Color? tertiary,
    Color? surfaceVariant,
    Color? surfaceContainer,
    Color? primaryLight,
    Color? secondaryLight,
  }) => AppColors(
    success: success ?? this.success,
    tertiary: tertiary ?? this.tertiary,
    surfaceVariant: surfaceVariant ?? this.surfaceVariant,
    surfaceContainer: surfaceContainer ?? this.surfaceContainer,
    primaryLight: primaryLight ?? this.primaryLight,
    secondaryLight: secondaryLight ?? this.secondaryLight,
  );

  @override
  AppColors lerp(AppColors? other, double t) => AppColors(
    success: Color.lerp(success, other?.success, t) ?? success,
    tertiary: Color.lerp(tertiary, other?.tertiary, t) ?? tertiary,
    surfaceVariant:
        Color.lerp(surfaceVariant, other?.surfaceVariant, t) ?? surfaceVariant,
    surfaceContainer:
        Color.lerp(surfaceContainer, other?.surfaceContainer, t) ??
        surfaceContainer,
    primaryLight:
        Color.lerp(primaryLight, other?.primaryLight, t) ?? primaryLight,
    secondaryLight:
        Color.lerp(secondaryLight, other?.secondaryLight, t) ?? secondaryLight,
  );
}
