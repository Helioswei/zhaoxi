/// 回收站保留策略：删除后 40 天自动清理（启动时执行）。
///
/// 真正的清理在 `TaskRepository.purgeOldDeleted`；这里只放"还剩几天"的计算，
/// 好让页面显示和单元测试用同一套规则。
library;

/// 保留天数（与后端的清理逻辑共用这一个常量）。
const int recycleRetentionDays = 40;

/// 距离被自动清理还剩几天。
///
/// - 不足一天按一天算（刚删完显示 40，隔了 39 天 12 小时显示 1）；
/// - 已经到期（或更久）返回 0，页面据此提示"今天就会被清理"。
int daysUntilPurge(int deletedAtMs, {DateTime? now}) {
  final deadline = DateTime.fromMillisecondsSinceEpoch(
    deletedAtMs,
  ).add(const Duration(days: recycleRetentionDays));
  final left = deadline.difference(now ?? DateTime.now());
  if (left.isNegative) return 0;
  return (left.inMinutes / Duration.minutesPerDay).ceil();
}
