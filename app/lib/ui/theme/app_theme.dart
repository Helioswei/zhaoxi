import 'package:flutter/material.dart';

import 'app_style.dart';

export 'app_style.dart' show AppStyleId, AppTokens;

/// 固定色：清单色点等不随风格变化的部分。
class AppColors {
  static const listWork = Color(0xFF3B6EA5);
  static const listLife = Color(0xFF3B7A6E);
}

/// 便捷访问：`context.tokens.primary`、`context.colors.onSurfaceVariant`。
extension AppThemeContext on BuildContext {
  AppTokens get tokens =>
      Theme.of(this).extension<AppTokens>() ??
      tokensFor(AppStyleId.fresh, Brightness.light);

  ColorScheme get colors => Theme.of(this).colorScheme;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;
}

ThemeData buildAppTheme({
  required AppStyleId style,
  required Brightness brightness,
}) {
  final t = tokensFor(style, brightness);

  final scheme = ColorScheme.fromSeed(
    seedColor: t.primary,
    brightness: brightness,
  ).copyWith(
    primary: t.primary,
    secondary: t.accent,
    surface: t.card,
    onSurface: t.textPrimary,
    onSurfaceVariant: t.textSecondary,
    error: t.danger,
  );

  final cardShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.cardRadius));
  final sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(t.sheetRadius)),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // 纸感风格用衬线；找不到时依次回退。
    fontFamily: t.fontFamily,
    fontFamilyFallback: t.isSerif
        ? const ['Noto Serif CJK SC', 'Noto Serif SC', 'STSong', 'serif']
        : null,
    scaffoldBackgroundColor: t.background,
    extensions: [t],
    appBarTheme: AppBarTheme(
      backgroundColor: t.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: t.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        fontFamily: t.fontFamily,
      ),
    ),
    cardTheme: CardThemeData(
      color: t.card,
      elevation: t.cardElevation,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.10),
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      shape: cardShape,
      textColor: t.textPrimary,
      iconColor: t.textSecondary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: t.chipSelectedBg,
      side: BorderSide.none,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: t.textSecondary,
        fontSize: 14,
        fontFamily: t.fontFamily,
      ),
      secondaryLabelStyle: TextStyle(
        color: t.primary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        fontFamily: t.fontFamily,
      ),
      shape: const StadiumBorder(),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      shape: sheetShape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.sheetRadius - 4),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.textPrimary,
      contentTextStyle: TextStyle(color: t.card, fontFamily: t.fontFamily),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: TextStyle(color: t.textSecondary, fontFamily: t.fontFamily),
    ),
    dividerTheme: DividerThemeData(
      color: t.divider,
      thickness: 1,
      space: 1,
    ),
  );
}

/// 清单色点：内置清单固定色，未知清单回退到主题主色。
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
