import 'package:flutter/material.dart';

/// 可选视觉风格。用户可在「设置 → 外观 → 风格」里实时切换、对比。
enum AppStyleId {
  fresh('fresh', '清爽', '简洁克制，信息优先'),
  warm('warm', '温润', '奶油底 · 大圆角 · 暖橘点缀'),
  paper('paper', '纸感', '米白纸底 · 衬线字 · 朱砂茶金');

  const AppStyleId(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static AppStyleId fromId(String? id) => values.firstWhere(
        (s) => s.id == id,
        orElse: () => AppStyleId.warm,
      );
}

/// 一套风格的视觉令牌（明/暗各一份）。所有组件只从这里取色与形状，
/// 换风格 = 换一套令牌，不动业务代码。
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.background,
    required this.card,
    required this.primary,
    required this.accent,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.chipSelectedBg,
    required this.divider,
    required this.cardRadius,
    required this.sheetRadius,
    required this.cardElevation,
    this.fontFamily,
  });

  final Color background;
  final Color card;

  /// 主色：按钮、完成圆点、选中文字。
  final Color primary;

  /// 点缀色：今天、进行中。
  final Color accent;

  final Color danger;
  final Color textPrimary;
  final Color textSecondary;
  final Color chipSelectedBg;
  final Color divider;

  final double cardRadius;
  final double sheetRadius;

  /// 卡片阴影强度（0 = 无阴影，仅靠圆角与底色区分）。
  final double cardElevation;

  /// 纸感风格用衬线字体；null = 系统默认。
  final String? fontFamily;

  bool get isSerif => fontFamily != null;

  @override
  AppTokens copyWith({
    Color? background,
    Color? card,
    Color? primary,
    Color? accent,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
    Color? chipSelectedBg,
    Color? divider,
    double? cardRadius,
    double? sheetRadius,
    double? cardElevation,
    String? fontFamily,
  }) =>
      AppTokens(
        background: background ?? this.background,
        card: card ?? this.card,
        primary: primary ?? this.primary,
        accent: accent ?? this.accent,
        danger: danger ?? this.danger,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        chipSelectedBg: chipSelectedBg ?? this.chipSelectedBg,
        divider: divider ?? this.divider,
        cardRadius: cardRadius ?? this.cardRadius,
        sheetRadius: sheetRadius ?? this.sheetRadius,
        cardElevation: cardElevation ?? this.cardElevation,
        fontFamily: fontFamily ?? this.fontFamily,
      );

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      chipSelectedBg: Color.lerp(chipSelectedBg, other.chipSelectedBg, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      sheetRadius: sheetRadius + (other.sheetRadius - sheetRadius) * t,
      cardElevation: cardElevation + (other.cardElevation - cardElevation) * t,
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
    );
  }
}

/// 各风格的明暗配色（色值均按 03 §6.1 的对比度思路挑选）。
AppTokens tokensFor(AppStyleId style, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  switch (style) {
    case AppStyleId.fresh:
      return dark
          ? const AppTokens(
              background: Color(0xFF121316),
              card: Color(0xFF1C1E22),
              primary: Color(0xFF6FBFAE),
              accent: Color(0xFF6FBFAE),
              danger: Color(0xFFFF6B6B),
              textPrimary: Color(0xFFEDEDED),
              textSecondary: Color(0xFF9BA1AA),
              chipSelectedBg: Color(0xFF24312E),
              divider: Color(0xFF2A2D33),
              cardRadius: 16,
              sheetRadius: 20,
              cardElevation: 0,
            )
          : const AppTokens(
              background: Color(0xFFF7F8FA),
              card: Color(0xFFFFFFFF),
              primary: Color(0xFF3B7A6E),
              accent: Color(0xFF3B7A6E),
              danger: Color(0xFFB3261E),
              textPrimary: Color(0xFF1A1A1A),
              textSecondary: Color(0xFF667085),
              chipSelectedBg: Color(0xFFE6F1EC),
              divider: Color(0xFFE7E9EE),
              cardRadius: 16,
              sheetRadius: 20,
              cardElevation: 0,
            );

    case AppStyleId.warm:
      return dark
          ? const AppTokens(
              background: Color(0xFF17151A),
              card: Color(0xFF221F26),
              primary: Color(0xFF74C7AF),
              accent: Color(0xFFF0B478),
              danger: Color(0xFFFF8A78),
              textPrimary: Color(0xFFF2ECE6),
              textSecondary: Color(0xFFA79E96),
              chipSelectedBg: Color(0xFF2A2B33),
              divider: Color(0xFF2E2B33),
              cardRadius: 22,
              sheetRadius: 28,
              cardElevation: 0,
              fontFamily: null,
            )
          : const AppTokens(
              background: Color(0xFFFBF8F3),
              card: Color(0xFFFFFFFF),
              primary: Color(0xFF3F8F7B),
              accent: Color(0xFFE9934E),
              danger: Color(0xFFC4553F),
              textPrimary: Color(0xFF33302E),
              textSecondary: Color(0xFF8C8880),
              chipSelectedBg: Color(0xFFE9F4EF),
              divider: Color(0xFFF0EAE1),
              cardRadius: 22,
              sheetRadius: 28,
              cardElevation: 1.5,
              fontFamily: null,
            );

    case AppStyleId.paper:
      return dark
          ? const AppTokens(
              background: Color(0xFF1A1815),
              card: Color(0xFF24201A),
              primary: Color(0xFFD8B25C),
              accent: Color(0xFFE0705A),
              danger: Color(0xFFE0705A),
              textPrimary: Color(0xFFEDE6DA),
              textSecondary: Color(0xFF9A8F82),
              chipSelectedBg: Color(0xFF322C22),
              divider: Color(0xFF332E26),
              cardRadius: 12,
              sheetRadius: 16,
              cardElevation: 0,
              fontFamily: 'ZhaoxiSerif',
            )
          : const AppTokens(
              background: Color(0xFFF5F0E8),
              card: Color(0xFFFDFAF4),
              primary: Color(0xFF9A6F16),
              accent: Color(0xFFB8860B),
              danger: Color(0xFFC23B22),
              textPrimary: Color(0xFF3C3530),
              textSecondary: Color(0xFF8B7E72),
              chipSelectedBg: Color(0xFFEDE3D2),
              divider: Color(0xFFD4C9B8),
              cardRadius: 12,
              sheetRadius: 16,
              cardElevation: 0,
              fontFamily: 'ZhaoxiSerif',
            );
  }
}
