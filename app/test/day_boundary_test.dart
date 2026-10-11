import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/day_boundary.dart';

void main() {
  group('DayBounds 本地日界', () {
    test('今天/明天边界', () {
      final b = DayBounds(DateTime(2026, 10, 12, 15, 30));
      expect(b.todayStart, DateTime(2026, 10, 12));
      expect(b.tomorrowStart, DateTime(2026, 10, 13));
      expect(b.dayAfterTomorrowStart, DateTime(2026, 10, 14));
    });

    test('周界固定为周一~周日（2026-10-12 是周一）', () {
      final b = DayBounds(DateTime(2026, 10, 12, 8));
      expect(b.weekStart, DateTime(2026, 10, 12));
      expect(b.nextWeekStart, DateTime(2026, 10, 19));

      // 周日归属当周，而不是下一周
      final sunday = DayBounds(DateTime(2026, 10, 18, 23, 59));
      expect(sunday.weekStart, DateTime(2026, 10, 12));
      expect(sunday.nextWeekStart, DateTime(2026, 10, 19));
    });

    test('月界跨年归一化', () {
      final dec = DayBounds(DateTime(2026, 12, 20));
      expect(dec.monthStart, DateTime(2026, 12, 1));
      expect(dec.nextMonthStart, DateTime(2027, 1, 1));
    });

    test('毫秒边界与本地时区一致（东八区）', () {
      final b = DayBounds(DateTime(2026, 10, 12, 15));
      // 本地 2026-10-13 00:00 对应的 UTC 毫秒
      expect(b.tomorrowStartMs, DateTime(2026, 10, 13).millisecondsSinceEpoch);
    });
  });

  group('planDateOnly', () {
    test('日期型：截止=当天 00:00，提醒=当天 09:00', () {
      final plan = planDateOnly(DateTime(2026, 10, 12));
      expect(plan.dueAt, DateTime(2026, 10, 12).millisecondsSinceEpoch);
      expect(plan.remindAt, DateTime(2026, 10, 12, 9).millisecondsSinceEpoch);
    });

    test('可自定义提醒时刻', () {
      final plan = planDateOnly(DateTime(2026, 10, 12), remindHour: 7);
      expect(plan.remindAt, DateTime(2026, 10, 12, 7).millisecondsSinceEpoch);
    });
  });

  test('isSameLocalDay', () {
    expect(
      isSameLocalDay(DateTime(2026, 10, 12, 1), DateTime(2026, 10, 12, 23)),
      isTrue,
    );
    expect(
      isSameLocalDay(DateTime(2026, 10, 12, 23), DateTime(2026, 10, 13, 0)),
      isFalse,
    );
  });
}
