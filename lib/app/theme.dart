import 'package:flutter/material.dart';

/// Hệ thiết kế chung của ứng dụng.
///
/// Tông sáng theo Miku: xanh ngọc của tóc (#39C5BB) cho mảng màu, xanh ngọc
/// đậm cho chữ/nút cần tương phản, hồng của trang phục model Live2D làm điểm
/// nhấn. Mọi màn (kể cả màn hội thoại) dùng nền sáng.
class MikuTheme {
  MikuTheme._();

  /// Xanh ngọc đậm — đủ tương phản cho chữ trắng trên nút và chữ trên nền sáng.
  static const Color primary = Color(0xFF0F7F7A);
  static const Color secondary = Color(0xFF39C5BB);

  /// Xanh ngọc Miku — chỉ dùng làm mảng màu/trang trí, không dùng cho chữ nhỏ.
  static const Color stageCyan = Color(0xFF39C5BB);
  static const Color accent = Color(0xFFE0508F);
  static const Color canvas = Color(0xFFF4FBFA);
  static const Color mint = Color(0xFFE2F6F3);
  static const Color blush = Color(0xFFFDEAF2);
  static const Color ink = Color(0xFF17323A);
  static const Color mutedInk = Color(0xFF5A7378);

  static const double radiusSmall = 12;
  static const double radiusMedium = 18;
  static const double radiusLarge = 28;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: accent,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primary.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(48, 52),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: primary.withValues(alpha: 0.08)),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        side: BorderSide(color: primary.withValues(alpha: 0.15)),
        selectedColor: primary.withValues(alpha: 0.14),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.1),
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
