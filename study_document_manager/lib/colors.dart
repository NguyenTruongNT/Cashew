import 'package:flutter/material.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG HỆ THỐNG GIAO DIỆN & MÀU SẮC (THEME & COLORS)]
// File: lib/colors.dart
// Mô tả: Dải màu chủ đề Tím–Xanh dương (Indigo–Blue Spectrum), chuyển màu
// mượt mà theo trạng thái & cấp độ. Light/Dark mode, Material 3 chuẩn.
// =====================================================================

class AppColors {
  // === DẢI MÀU CHỦ ĐẠO: INDIGO–VIOLET–BLUE ===
  // Primary: Indigo đậm — thể hiện sự tri thức, chuyên nghiệp
  static const Color primary        = Color(0xFF4F46C7); // Indigo
  static const Color primaryDark    = Color(0xFF3730A3); // Deep indigo
  static const Color primaryDeep    = Color(0xFF312E81); // Navy indigo
  static const Color primaryLight   = Color(0xFFA5B4FC); // Soft indigo

  // Accent: Xanh tím nhạt — điểm nhấn tươi sáng
  static const Color accent         = Color(0xFF7C3AED); // Violet
  static const Color accentLight    = Color(0xFFC4B5FD); // Soft violet

  // Secondary: Xanh dương nhẹ — hành động phụ
  static const Color secondary      = Color(0xFF3B82F6); // Blue
  static const Color secondaryLight = Color(0xFFBFDBFE); // Soft blue

  // === MÀU PHÂN LOẠI TÀI LIỆU ===
  // Màu được chọn từ dải hài hòa (analogous), dễ phân biệt, không loé mắt
  static const Color lectureColor    = Color(0xFF2563EB); // Blue — Bài giảng
  static const Color assignmentColor = Color(0xFF7C3AED); // Violet — Bài tập
  static const Color referenceColor  = Color(0xFF0F8B83); // Teal — Tham khảo
  static const Color examColor       = Color(0xFF4F46C7); // Indigo — Đề thi

  // === TRẠNG THÁI (STATUS) ===
  static const Color success  = Color(0xFF16835D);
  static const Color warning  = Color(0xFFB7791F);
  static const Color error    = Color(0xFFC2414B);
  static const Color info     = Color(0xFF2563EB);

  // Trạng thái tài liệu — dải nhẹ nhàng
  static const Color statusPending    = Color(0xFFB7791F);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusCompleted  = Color(0xFF16835D);

  // Mức ưu tiên
  static const Color priorityLow    = Color(0xFF64748B);
  static const Color priorityMedium = Color(0xFF4F46C7);
  static const Color priorityHigh   = Color(0xFFD1435B);

  // === LIGHT THEME SURFACES ===
  static const Color backgroundLight = Color(0xFFF5F6FC);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color cardLight       = Color(0xFFFFFFFF);
  static const Color textPrimaryLight   = Color(0xFF1A1C2E); // Gần đen tối xanh
  static const Color textSecondaryLight = Color(0xFF59617A);
  static const Color textHintLight      = Color(0xFF7A829A);
  static const Color borderLight        = Color(0xFFE2E5F0);
  static const Color dividerLight       = Color(0xFFEEEFF7);

  // === DARK THEME SURFACES ===
  static const Color backgroundDark = Color(0xFF111322);
  static const Color surfaceDark    = Color(0xFF191C30);
  static const Color cardDark       = Color(0xFF20243B);
  static const Color textPrimaryDark   = Color(0xFFE9EBF8);
  static const Color textSecondaryDark = Color(0xFFB2B9D0);
  static const Color textHintDark      = Color(0xFF929AB4);
  static const Color borderDark        = Color(0xFF343951);
  static const Color dividerDark       = Color(0xFF2B3047);

  // === GRADIENT PRESETS ===
  static const LinearGradient bannerGradient = LinearGradient(
    colors: [Color(0xFF4F46C7), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient urgentGradient = LinearGradient(
    colors: [Color(0xFFB7791F), Color(0xFFC2414B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// =====================================================================
// LIGHT THEME
// =====================================================================
ThemeData getLightTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surfaceLight,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.backgroundLight,
    primaryColor: AppColors.primary,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceLight,
      foregroundColor: AppColors.textPrimaryLight,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryLight,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.primary, size: 22),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.backgroundLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textHintLight, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderLight, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.backgroundLight,
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.borderLight),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
      space: 1,
    ),

    // Text
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w800),
      headlineLarge: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 15),
      titleSmall: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 13),
      bodyLarge: TextStyle(color: AppColors.textPrimaryLight, fontSize: 15, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13, height: 1.4),
      bodySmall: TextStyle(color: AppColors.textHintLight, fontSize: 12),
      labelLarge: TextStyle(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600, fontSize: 14),
    ),
  );
}

// =====================================================================
// DARK THEME
// =====================================================================
ThemeData getDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.accentLight,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.backgroundDark,
    primaryColor: AppColors.primaryLight,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surfaceDark,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimaryDark,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.primaryLight, size: 22),
    ),

    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textHintDark, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.cardDark,
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textPrimaryDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: AppColors.borderDark),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.backgroundDark,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 1,
      space: 1,
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w800),
      headlineLarge: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 15),
      titleSmall: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 13),
      bodyLarge: TextStyle(color: AppColors.textPrimaryDark, fontSize: 15, height: 1.5),
      bodyMedium: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.4),
      bodySmall: TextStyle(color: AppColors.textHintDark, fontSize: 12),
      labelLarge: TextStyle(color: AppColors.textPrimaryDark, fontWeight: FontWeight.w600, fontSize: 14),
    ),
  );
}
