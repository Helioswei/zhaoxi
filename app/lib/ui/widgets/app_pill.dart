import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 胶囊标签（选中态填充浅底 + 主色文字，无边框）。
/// 比 Material 默认 ChoiceChip 更柔和，也更像"导航"而不是"表单控件"。
///
/// 触控规范：自身高度 ≥44，间距 ≥8（DESIGN.md Do's）。
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.dotColor,
    this.dense = false,
    this.outlined = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 非空时在文字前显示一个色点（用于清单）。
  final Color? dotColor;

  final bool dense;

  /// 未选中态描边（用于和时间视图 Tab 区分两个筛选行）。
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
      child: Material(
        color: selected ? t.chipSelectedBg : Colors.transparent,
        shape: outlined && !selected
            ? StadiumBorder(side: BorderSide(color: t.divider))
            : const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Semantics(
            button: true,
            selected: selected,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: dense ? 12 : 14,
                vertical: dense ? 13 : 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dotColor != null) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      color: selected ? t.primary : t.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 小信息胶囊：时间、逾期、重复等。
class AppBadge extends StatelessWidget {
  const AppBadge(this.text, {super.key, required this.color, this.background});

  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
          fontFamily: t.fontFamily,
        ),
      ),
    );
  }
}

/// 空状态：一个圆润的图形 + 一句话 +（可选）一个行动按钮。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.emoji,
    required this.text,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  final String emoji;
  final String text;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.chipSelectedBg,
              shape: BoxShape.circle,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 40)),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: t.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: TextStyle(fontSize: 13, color: t.textSecondary),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
