/// 提醒排程的抽象。数据层通过它触发系统通知，避免反向依赖具体实现。
abstract class ReminderScheduler {
  /// 排一条通知。返回是否真的排上了（权限不足/时间已过 → false）。
  Future<bool> schedule(int id, String title, DateTime when, String taskId);

  Future<void> cancel(int id);
}

/// 测试与未接入平台时的空实现。
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<bool> schedule(int id, String title, DateTime when, String taskId) async =>
      false;

  @override
  Future<void> cancel(int id) async {}
}
