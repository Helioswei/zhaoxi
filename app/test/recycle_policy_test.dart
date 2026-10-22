import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/recycle_policy.dart';

void main() {
  group('回收站剩余天数', () {
    final deletedAt = DateTime(2026, 10, 1, 12);

    int left(DateTime now) =>
        daysUntilPurge(deletedAt.millisecondsSinceEpoch, now: now);

    test('刚删除时显示完整保留期', () {
      expect(left(deletedAt), recycleRetentionDays);
    });

    test('过了一天少一天', () {
      expect(left(deletedAt.add(const Duration(days: 1))), recycleRetentionDays - 1);
      expect(left(deletedAt.add(const Duration(days: 20))), recycleRetentionDays - 20);
    });

    test('不足一天按一天算（不会提前显示 0）', () {
      expect(
        left(deletedAt.add(const Duration(days: 39, hours: 12))),
        1,
      );
    });

    test('到期当天就是 0，超期也是 0', () {
      expect(left(deletedAt.add(const Duration(days: 40))), 0);
      expect(left(deletedAt.add(const Duration(days: 45))), 0);
    });

    test('保留期常量就是页面和清理共用的那个', () {
      expect(recycleRetentionDays, 40);
    });
  });
}
