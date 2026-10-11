import 'package:flutter/material.dart';

/// 固定色（清单色点等不随主题变化的部分）。
/// 其余语义色一律走 [ColorScheme]，以支持深色模式。
class AppColors {
  static const listWork = Color(0xFF3B6EA5);
  static const listLife = Color(0xFF3B7A6E);

  // 浅色 / 深色的原始值，供主题构造使用（03 §6.1 实测达标）。
  static const lightPrimary = Color(0xFF3B7A6E);
  static const lightDanger = Color(0xFFB3261E);
  static const lightBg = Color(0xFFF7F8FA);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF667085);

  static const darkPrimary = Color(0xFF6FBFAE);
  static const darkDanger = Color(0xFFFF6B6B);
  static const darkBg = Color(0xFF121316);
  static const darkCard = Color(0xFF1C1E22);
  static const darkText = Color(0xFFEDEDED);
  static const darkTextSecondary = Color(0xFF9BA1AA);
}

/// 便捷访问语义色：`context.colors.onSurfaceVariant`。
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = dark ? AppColors.darkPrimary : AppColors.lightPrimary;
  final danger = dark ? AppColors.darkDanger : AppColors.lightDanger;
  final bg = dark ? AppColors.darkBg : AppColors.lightBg;
  final card = dark ? AppColors.darkCard : AppColors.lightCard;
  final text = dark ? AppColors.darkText : AppColors.lightText;
  final secondary =
      dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    surface: card,
    onSurface: text,
    onSurfaceVariant: secondary,
    error: danger,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: bg,
    dialogTheme: DialogThemeData(backgroundColor: card),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: card),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: secondary),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xFF2A2D33) : const Color(0xFFE7E9EE),
      thickness: 1,
      space: 1,
    ),
  );
}

/// 清单色点：内置清单按固定色，未知清单回退到主题主色。
Color listColor(String listId, String? colorHex, Color fallback) {
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
      return fallback;
  }
}
