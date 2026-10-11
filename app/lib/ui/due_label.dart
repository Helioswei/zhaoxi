import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db/database.dart';
import '../domain/day_boundary.dart';
import '../ui/theme/app_theme.dart';

final _hm = DateFormat('HH:mm');
final _md = DateFormat('M月d日');

/// 任务条目的时间标签（文案 + 是否逾期）。
class DueLabel {
  const DueLabel(this.text, {this.overdue = false});

  final String text;
  final bool overdue;
}

DueLabel dueLabel(Task task, [DateTime? at]) {
  final now = at ?? DateTime.now();
  final dueAt = task.dueAt;
  if (dueAt == null) return const DueLabel('待定');

  final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
  final bounds = DayBounds(now);
  final isOverdue = task.dueHasTime ? due.isBefore(now) : due.isBefore(bounds.todayStart);

  final String text;
  if (isSameLocalDay(due, bounds.todayStart)) {
    text = task.dueHasTime ? '今天 ${_hm.format(due)}' : '今天';
  } else if (isSameLocalDay(due, bounds.tomorrowStart)) {
    text = task.dueHasTime ? '明天 ${_hm.format(due)}' : '明天';
  } else if (isSameLocalDay(due, bounds.todayStart.subtract(const Duration(days: 1)))) {
    text = '昨天';
  } else {
    text = _md.format(due);
  }
  return DueLabel(text, overdue: isOverdue);
}

Color dueLabelColor(DueLabel label) {
  if (label.text == '待定') return AppColors.textSecondary;
  if (label.overdue) return AppColors.danger;
  if (label.text.startsWith('今天')) return AppColors.primary;
  return AppColors.textSecondary;
}
