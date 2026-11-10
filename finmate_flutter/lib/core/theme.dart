import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const violet = Color(0xFF6C5CE7);
  static const coral = Color(0xFFFF7A90);
  static const mint = Color(0xFF2BD9B4);
  static const amber = Color(0xFFFFC46B);
  static const sky = Color(0xFF5AA9FF);
  static const lightBackground = Color(0xFFFBF8F4);
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF172033);
  static const darkField = Color(0xFF1E293B);
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFFB6A9FF) : AppColors.violet,
    onPrimary: isDark ? const Color(0xFF21154D) : Colors.white,
    secondary: isDark ? const Color(0xFF7AEBD0) : const Color(0xFF00A88B),
    onSecondary: isDark ? const Color(0xFF042A24) : Colors.white,
    tertiary: isDark ? const Color(0xFFFFA3B5) : AppColors.coral,
    onTertiary: isDark ? const Color(0xFF3D1020) : Colors.white,
    surface: isDark ? AppColors.darkSurface : Colors.white,
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1F2430),
    surfaceContainerHighest:
        isDark ? const Color(0xFF263247) : const Color(0xFFF3EFE9),
  );

  final baseText = isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
  final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseText).copyWith(
    displaySmall: GoogleFonts.plusJakartaSans(
        fontSize: 34, fontWeight: FontWeight.w800, color: scheme.onSurface),
    headlineSmall: GoogleFonts.plusJakartaSans(
        fontSize: 26, fontWeight: FontWeight.w800, color: scheme.onSurface),
    titleLarge: GoogleFonts.plusJakartaSans(
        fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
    titleMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurface),
    bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16, fontWeight: FontWeight.w500, color: scheme.onSurface),
    bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w500, color: scheme.onSurface),
    bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface.withValues(alpha: 0.65)),
    labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
  );

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide.none,
  );
  final enabledBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9E2DA)),
  );
  final focusedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide(color: scheme.primary, width: 1.6),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.darkBackground : AppColors.lightBackground,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface),
      iconTheme: IconThemeData(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkField : const Color(0xFFF6F2EE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: inputBorder,
      enabledBorder: enabledBorder,
      focusedBorder: focusedBorder,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.45)),
      labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.7)),
      prefixIconColor: scheme.onSurface.withValues(alpha: 0.55),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        minimumSize: const Size(48, 52),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.35)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF121C31) : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withValues(alpha: 0.16),
      elevation: 0,
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.55));
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    searchBarTheme: SearchBarThemeData(
      backgroundColor: WidgetStatePropertyAll(
          isDark ? AppColors.darkField : Colors.white),
      overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06)),
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(
          BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9E2DA))),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
      hintStyle: WidgetStatePropertyAll(textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withValues(alpha: 0.45))),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.16);
          }
          return Colors.transparent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurface.withValues(alpha: 0.6);
        }),
        side: WidgetStatePropertyAll(
            BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE9E2DA))),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF263247) : const Color(0xFF1F2430),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFEDE7E0),
      thickness: 1,
      space: 1,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.onPrimary;
        return scheme.onSurface.withValues(alpha: 0.6);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.onSurface.withValues(alpha: 0.14);
      }),
    ),
  );
}

final finMateLightTheme = _buildTheme(Brightness.light);
final finMateDarkTheme = _buildTheme(Brightness.dark);

// Backwards-compatible alias.
final finMateTheme = finMateLightTheme;
