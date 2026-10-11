import 'package:flutter/material.dart';

/// 与 03 §6.1 定稿色值一致。
class AppColors {
  static const primary = Color(0xFF3B7A6E);
  static const danger = Color(0xFFB3261E);
  static const background = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF667085);
  static const listWork = Color(0xFF3B6EA5);
  static const listLife = Color(0xFF3B7A6E);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: AppColors.textSecondary),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE7E9EE),
      thickness: 1,
      space: 1,
    ),
  );
}

/// 清单色点：内置清单按固定色，未知清单回退到主色。
Color listColor(String listId, String? colorHex) {
  if (colorHex != null && colorHex.startsWith('#') && colorHex.length == 7) {
    final value = int.tryParse(colorHex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  switch (listId) {
    case 'list-work':
      return AppColors.listWork;
    case 'list-life':
      return AppColors.listLife;
    default:
      return AppColors.primary;
  }
}
