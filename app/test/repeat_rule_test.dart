import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/repeat_rule.dart';

void main() {
  // 2026-10-12 是周一；10-14 周三；10-19 周一。
  DateTime at(int y, int m, int d, [int h = 9, int min = 0]) =>
      DateTime(y, m, d, h, min);

  group('每天', () {
    test('推进到 after 之后的下一天（保留时分）', () {
      final r = RepeatRule.daily();
      final next = r.advance(at(2026, 10, 12, 9), at(2026, 10, 12, 12));
      expect(next, at(2026, 10, 13, 9));
    });

    test('逾期多期不逐格补，直接跳到下一个未来点', () {
      final r = RepeatRule.daily();
      final next = r.advance(at(2026, 10, 1, 9), at(2026, 10, 20, 8));
      expect(next, at(2026, 10, 20, 9));
    });

    test('反推上一天', () {
      expect(RepeatRule.daily().previous(at(2026, 10, 13, 9)),
          at(2026, 10, 12, 9));
    });
  });

  group('每 N 天', () {
    test('按间隔推进', () {
      final r = RepeatRule.everyDays(3);
      expect(r.advance(at(2026, 10, 12), at(2026, 10, 12, 12)),
          at(2026, 10, 15));
    });

    test('间隔小于 1 会被夹到 1', () {
      expect(RepeatRule.everyDays(0).intervalDays, 1);
    });
  });

  group('每周', () {
    test('单个星期几：周三 → 下周三', () {
      final r = RepeatRule.weekly(at(2026, 10, 14)); // 周三
      expect(r.byWeekday, [DateTime.wednesday]);
      expect(r.advance(at(2026, 10, 14), at(2026, 10, 14, 12)),
          at(2026, 10, 21));
    });

    test('多个星期几：周一、周三 → 周一的下一站是周三', () {
      const r = RepeatRule(
        freq: RepeatFreq.weekly,
        byWeekday: [DateTime.monday, DateTime.wednesday],
      );
      expect(r.advance(at(2026, 10, 12), at(2026, 10, 12, 12)), at(2026, 10, 14));
      expect(r.advance(at(2026, 10, 14), at(2026, 10, 14, 12)), at(2026, 10, 19));
    });

    test('反推上一个星期几', () {
      const r = RepeatRule(freq: RepeatFreq.weekly, byWeekday: [DateTime.monday]);
      expect(r.previous(at(2026, 10, 19)), at(2026, 10, 12));
    });
  });

  group('每月', () {
    test('推进到下个月同一天', () {
      expect(RepeatRule.monthly().advance(at(2026, 10, 15), at(2026, 10, 20)),
          at(2026, 11, 15));
    });

    test('月末会被夹到当月最后一天（1/31 → 2/28）', () {
      expect(RepeatRule.monthly().advance(at(2026, 1, 31), at(2026, 2, 1)),
          at(2026, 2, 28));
    });

    test('反推上个月（3/31 → 2/28）', () {
      expect(RepeatRule.monthly().previous(at(2026, 3, 31)), at(2026, 2, 28));
    });
  });

  group('编解码', () {
    test('往返一致', () {
      final r = RepeatRule(freq: RepeatFreq.weekly, byWeekday: [3]);
      final decoded = RepeatRule.decode(r.encode())!;
      expect(decoded.freq, RepeatFreq.weekly);
      expect(decoded.byWeekday, [3]);
    });

    test('空 / 损坏 → null', () {
      expect(RepeatRule.decode(null), isNull);
      expect(RepeatRule.decode(''), isNull);
      expect(RepeatRule.decode('not json'), isNull);
    });

    test('非法星期几被过滤', () {
      final decoded = RepeatRule.decode('{"freq":"weekly","byWeekday":[0,3,9]}')!;
      expect(decoded.byWeekday, [3]);
    });
  });
}
