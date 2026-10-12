import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/repeat_rule.dart';
import '../../domain/sort_order.dart';
import '../../domain/task_filter.dart';
import '../../services/reminder_scheduler.dart';
import '../dao/settings_dao.dart';
import '../db/database.dart';

/// 任务的读写入口。所有业务规则（时间戳、软删、ID 生成、提醒排程）都集中在这里。
class TaskRepository {
  TaskRepository(this._db, [this._scheduler = const NoopReminderScheduler()]);

  final AppDatabase _db;
  final ReminderScheduler _scheduler;
  static const _uuid = Uuid();
  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  Stream<List<Task>> watch(TaskFilter filter) => _db.taskDao.watch(filter);

  Stream<int> watchUndatedCount({String? listId}) =>
      _db.taskDao.watchUndatedCount(listId: listId);

  Future<Task?> findById(String id) => _db.taskDao.findById(id);

  /// 本机设备标识，首次访问时生成并持久化。
  Future<String> ensureDeviceId() async {
    final existing = await _db.settingsDao.get(SettingsKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await _db.settingsDao.set(SettingsKeys.deviceId, id);
    return id;
  }

  Future<String> createTask({
    required String title,
    required String listId,
    String? note,
    int? dueAt,
    bool dueHasTime = false,
    int? remindAt,
    String? repeatRule,
  }) async {
    final now = _nowMs();
    final device = await ensureDeviceId();
    final id = _uuid.v4();
    final sortOrder = await _db.taskDao.nextSortOrder();
    await _db.taskDao.upsert(
      TasksCompanion.insert(
        id: id,
        title: title,
        listId: listId,
        note: Value(note),
        dueAt: Value(dueAt),
        dueHasTime: Value(dueHasTime),
        remindAt: Value(remindAt),
        repeatRule: Value(repeatRule),
        sortOrder: Value(sortOrder),
        createdAt: now,
        updatedAt: now,
        originDevice: device,
      ),
    );
    await _syncReminder(await _db.taskDao.findById(id));
    return id;
  }

  Future<void> updateTask({
    required String id,
    required String title,
    required String listId,
    String? note,
    int? dueAt,
    bool dueHasTime = false,
    int? remindAt,
    String? repeatRule,
  }) async {
    await _db.taskDao.patch(
      id,
      TasksCompanion(
        title: Value(title),
        listId: Value(listId),
        note: Value(note),
        dueAt: Value(dueAt),
        dueHasTime: Value(dueHasTime),
        remindAt: Value(remindAt),
        repeatRule: Value(repeatRule),
        updatedAt: Value(_nowMs()),
      ),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

  /// 完成 / 取消完成。
  ///
  /// 重复任务：**原地推进**——`dueAt` 跳到下一个未来点、`completedCount+1`、
  /// `status` 保持 0（不进已完成列表），并重排通知（见 02 §2.4.2 / 05 §九）。
  Future<void> setCompleted(Task task, bool done) async {
    final now = _nowMs();
    final rule = RepeatRule.decode(task.repeatRule);

    if (done && rule != null && task.dueAt != null) {
      await _advanceRepeat(task, rule, now);
      return;
    }

    await _db.taskDao.patch(
      task.id,
      done
          ? TasksCompanion(
              status: const Value(1),
              completedAt: Value(now),
              updatedAt: Value(now),
            )
          : TasksCompanion(
              status: const Value(0),
              completedAt: const Value<int?>(null),
              updatedAt: Value(now),
            ),
    );
    await _syncReminder(await _db.taskDao.findById(task.id));
  }

  Future<void> _advanceRepeat(Task task, RepeatRule rule, int now) async {
    final dueAt = task.dueAt!;
    final current = DateTime.fromMillisecondsSinceEpoch(dueAt);
    final next = rule.advance(current, DateTime.now());
    final nextMs = next.millisecondsSinceEpoch;

    final reachedCount =
        rule.count != null && task.completedCount + 1 >= rule.count!;
    final pastUntil = rule.until != null && nextMs > rule.until!;

    if (reachedCount || pastUntil) {
      // 系列结束 → 正常完成，清掉重复规则。
      await _db.taskDao.patch(
        task.id,
        TasksCompanion(
          status: const Value(1),
          completedAt: Value(now),
          completedCount: Value(task.completedCount + 1),
          repeatRule: const Value<String?>(null),
          updatedAt: Value(now),
        ),
      );
      await _syncReminder(await _db.taskDao.findById(task.id));
      return;
    }

    // 保留原有的"提醒相对截止"的提前量。
    int? nextRemind;
    if (task.remindAt != null) {
      nextRemind = nextMs - (dueAt - task.remindAt!);
    }

    await _db.taskDao.patch(
      task.id,
      TasksCompanion(
        dueAt: Value(nextMs),
        remindAt: Value(nextRemind),
        completedCount: Value(task.completedCount + 1),
        completedAt: Value(now),
        status: const Value(0),
        updatedAt: Value(now),
      ),
    );
    await _syncReminder(await _db.taskDao.findById(task.id));
  }

  /// 撤销一次"重复任务完成"：把 [before] 里的字段原样写回。
  Future<void> restoreRepeatCompletion(Task before) async {
    await _db.taskDao.patch(
      before.id,
      TasksCompanion(
        dueAt: Value(before.dueAt),
        remindAt: Value(before.remindAt),
        completedCount: Value(before.completedCount),
        completedAt: Value(before.completedAt),
        repeatRule: Value(before.repeatRule),
        status: Value(before.status),
        updatedAt: Value(_nowMs()),
      ),
    );
    await _syncReminder(await _db.taskDao.findById(before.id));
  }

  Future<void> softDelete(String id) async {
    await _db.taskDao.patch(
      id,
      TasksCompanion(deleted: const Value(true), updatedAt: Value(_nowMs())),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

  // -------------------------------------------------------------- 回收站

  Stream<List<Task>> watchDeleted() => _db.taskDao.watchDeleted();

  /// 彻底删除（不可恢复）。
  Future<void> hardDelete(String id) => _db.taskDao.hardDelete(id);

  Future<void> hardDeleteAll() => _db.taskDao.hardDeleteAll();

  /// 清理 30 天前删除的记录，返回清理条数。
  Future<int> purgeOldDeleted() => _db.taskDao.purgeDeletedOlderThan(
        _nowMs() - const Duration(days: 30).inMilliseconds,
      );

  Future<void> restore(String id) async {
    await _db.taskDao.patch(
      id,
      TasksCompanion(deleted: const Value(false), updatedAt: Value(_nowMs())),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

  /// 启动时重排全部未来提醒（应对重启/时区变化）。
  Future<void> rescheduleAll() async {
    final tasks = await _db.taskDao.futureReminders(_nowMs());
    for (final t in tasks) {
      await _syncReminder(t);
    }
  }

  // -------------------------------------------------------------- 手工排序

  /// 「全部」视图内的**组内**拖拽排序；也用于其他视图的"同一时间槽内"微调。
  ///
  /// [beforeId] / [afterId] 是插入位置的左右邻居任务（分组头视为 null）。
  Future<void> reorderWithinGroup({
    required String movedId,
    String? beforeId,
    String? afterId,
    bool retried = false,
  }) async {
    final all = await _db.taskDao.allOrderedBySort();
    final byId = {for (final t in all) t.id: t};
    // 忽略自己作为邻居的情况（防御）
    final before =
        (beforeId == null || beforeId == movedId) ? null : byId[beforeId]?.sortOrder;
    final after =
        (afterId == null || afterId == movedId) ? null : byId[afterId]?.sortOrder;

    if (!retried && needsRenormalize(before, after)) {
      await renormalizeSortOrders();
      await reorderWithinGroup(
        movedId: movedId,
        beforeId: beforeId,
        afterId: afterId,
        retried: true,
      );
      return;
    }

    final value = sortOrderBetween(before, after);
    if (value == null) return;
    await _db.taskDao.patchSortOrder(movedId, value);
  }

  /// 整表重排为 1024, 2048, 3072 …
  Future<void> renormalizeSortOrders() async {
    final all = await _db.taskDao.allOrderedBySort();
    await _db.taskDao.applySortOrders(renormalized(all.map((t) => t.id)));
  }

  /// 取消旧通知 → 未完成且提醒时间在未来 → 排新通知。
  Future<void> _syncReminder(Task? task) async {
    if (task == null) return;
    if (task.notifId != null) {
      await _scheduler.cancel(task.notifId!);
    }
    if (task.status != 0 || task.deleted) return;
    final remindAt = task.remindAt;
    if (remindAt == null) return;
    if (remindAt <= _nowMs()) return; // 已过则不排（见 02 §2.3.2）

    var notifId = task.notifId;
    if (notifId == null) {
      notifId = await _allocateNotifId();
      await _db.taskDao.patch(
        task.id,
        TasksCompanion(
          notifId: Value(notifId),
          updatedAt: Value(_nowMs()),
        ),
      );
    }
    await _scheduler.schedule(
      notifId,
      task.title,
      DateTime.fromMillisecondsSinceEpoch(remindAt),
      task.id,
    );
  }

  /// 通知 ID 用自增整数（Android ID 是 32 位 int，UUID 哈希会碰撞）。
  Future<int> _allocateNotifId() async {
    final current = int.tryParse(
          await _db.settingsDao.get(SettingsKeys.notifIdCounter) ?? '',
        ) ??
        1;
    await _db.settingsDao.set(SettingsKeys.notifIdCounter, '${current + 1}');
    return current;
  }
}
