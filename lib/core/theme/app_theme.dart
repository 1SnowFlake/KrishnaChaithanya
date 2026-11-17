import 'package:flutter/material.dart';

// ============================================================
// SEMANTIC COLOR TOKENS
// Use these across all screens instead of raw Colors.green etc.
// They are chosen to meet WCAG AA contrast on both light and
// dark backgrounds.
// ============================================================
class AppColors {
  AppColors._();

  // Seed – calm school blue (Material Light Blue 800).
  // Generates a full M3 tonal palette.
  static const Color seed = Color(0xFF0277BD);

  // ── Attendance status ────────────────────────────────────
  // Both colors tested for ≥ 4.5:1 contrast against white AND
  // the dark surface Color(0xFF1E293B).
  static const Color present = Color(0xFF2E7D32);       // Green 800
  static const Color presentSurface = Color(0xFFE8F5E9); // Green 50
  static const Color presentDark = Color(0xFF81C784);    // Green 300 (on dark bg)
  static const Color presentSurfaceDark = Color(0xFF1B3A1C); // dark tint

  static const Color absent = Color(0xFFC62828);        // Red 800
  static const Color absentSurface = Color(0xFFFFEBEE);  // Red 50
  static const Color absentDark = Color(0xFFEF9A9A);     // Red 200 (on dark bg)
  static const Color absentSurfaceDark = Color(0xFF3B1212); // dark tint

  // ── Sync / connectivity ──────────────────────────────────
  static const Color offline = Color(0xFFE65100);        // Deep Orange 900
  static const Color offlineSurface = Color(0xFFFBE9E7);
  static const Color syncing = Color(0xFF01579B);        // Light Blue 900
  static const Color syncingSurface = Color(0xFFE1F5FE);

  // ── Holiday / closed ─────────────────────────────────────
  static const Color holiday = Color(0xFF6A1B9A);        // Purple 800
  static const Color holidaySurface = Color(0xFFF3E5F5);

  // ── Warning / substitute ─────────────────────────────────
  static const Color substitute = Color(0xFF1565C0);     // Blue 800
  static const Color substituteSurface = Color(0xFFE3F2FD);
}

// ============================================================
// SPACING, RADIUS & ELEVATION CONSTANTS
// ============================================================
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

class AppElevation {
  AppElevation._();
  static const double none = 0;
  static const double low = 1.0;
  static const double medium = 2.0;
  static const double high = 4.0;
}

// ============================================================
// THEME
// ============================================================
class AppTheme {
  AppTheme._();

  // ── Light Theme ──────────────────────────────────────────
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.light,
    );
    return _build(cs);
  }

  // ── Dark Theme ───────────────────────────────────────────
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: Brightness.dark,
    );
    return _build(cs);
  }

  // ── Shared builder ───────────────────────────────────────
  static ThemeData _build(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F8FC),

      // ── Text ───────────────────────────────────────────
      textTheme: const TextTheme(
        // Display / Headline
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        headlineSmall:  TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        // Title
        titleLarge:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        // Body – min 14sp
        bodyLarge:   TextStyle(fontSize: 16),
        bodyMedium:  TextStyle(fontSize: 14),
        bodySmall:   TextStyle(fontSize: 13),
        // Label / Caption
        labelLarge:  TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall:  TextStyle(fontSize: 11),
      ),

      // ── AppBar ─────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1.5,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        titleTextStyle: TextStyle(
          color: cs.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actionsIconTheme: IconThemeData(color: cs.onPrimary),
      ),

      // ── Card ───────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),

      // ── Buttons ────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      // ── TextField / Input ──────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        labelStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
        hintStyle: TextStyle(fontSize: 14, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
        errorStyle: TextStyle(fontSize: 12, color: cs.error),
      ),

      // ── Chip ───────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),

      // ── Dialog ─────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),

      // ── Bottom Sheet ───────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // ── Snackbar ───────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // ── ListTile ───────────────────────────────────────
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        titleTextStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),

      // ── Divider ────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        space: 1,
        thickness: 1,
      ),

      // ── NavigationBar & BottomNavigationBar ────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 1,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        indicatorColor: cs.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary);
          }
          return TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant);
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
