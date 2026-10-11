/// 本地时区的"日界"计算。
///
/// 存储层一律用 UTC 毫秒；"今天/明天/本周/本月"必须在**本地时区**算出边界，
/// 再转成毫秒去和存储值比较。所有这类计算集中在这里，禁止散落各处。
///
/// 周界固定为 **周一 ~ 周日**。
class DayBounds {
  DayBounds([DateTime? at]) : now = at ?? DateTime.now();

  final DateTime now;

  DateTime get todayStart => DateTime(now.year, now.month, now.day);

  DateTime get tomorrowStart => DateTime(now.year, now.month, now.day + 1);

  DateTime get dayAfterTomorrowStart =>
      DateTime(now.year, now.month, now.day + 2);

  /// 本周一 00:00。用"构造日期"而非 `subtract(Duration)`，避免夏令时偏移。
  DateTime get weekStart => DateTime(
        now.year,
        now.month,
        now.day - (todayStart.weekday - DateTime.monday),
      );

  DateTime get nextWeekStart =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

  DateTime get monthStart => DateTime(now.year, now.month, 1);

  /// Dart 会自动把 month=13 归一化到次年 1 月。
  DateTime get nextMonthStart => DateTime(now.year, now.month + 1, 1);

  int get todayStartMs => todayStart.millisecondsSinceEpoch;
  int get tomorrowStartMs => tomorrowStart.millisecondsSinceEpoch;
  int get dayAfterTomorrowStartMs => dayAfterTomorrowStart.millisecondsSinceEpoch;
  int get weekStartMs => weekStart.millisecondsSinceEpoch;
  int get nextWeekStartMs => nextWeekStart.millisecondsSinceEpoch;
  int get monthStartMs => monthStart.millisecondsSinceEpoch;
  int get nextMonthStartMs => nextMonthStart.millisecondsSinceEpoch;
}

/// 日期型任务（`due_has_time = false`）的默认时间计划：
/// 截止 = 当天本地 00:00，提醒 = 当天本地 [remindHour]:00。
class DateOnlyPlan {
  const DateOnlyPlan({required this.dueAt, required this.remindAt});

  final int dueAt;
  final int remindAt;
}

DateOnlyPlan planDateOnly(DateTime day, {int remindHour = 9}) {
  final due = DateTime(day.year, day.month, day.day);
  final remind = DateTime(day.year, day.month, day.day, remindHour);
  return DateOnlyPlan(
    dueAt: due.millisecondsSinceEpoch,
    remindAt: remind.millisecondsSinceEpoch,
  );
}

/// 判断"是否同一天"（本地时区）。
bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
