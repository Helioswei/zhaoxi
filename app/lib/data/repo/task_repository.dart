import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> createTask({
    required String title,
    required String listId,
    String? note,
    int? dueAt,
    bool dueHasTime = false,
    int? remindAt,
  }) async {
    final now = _nowMs();
    final device = await ensureDeviceId();
    final id = _uuid.v4();
    await _db.taskDao.upsert(
      TasksCompanion.insert(
        id: id,
        title: title,
        listId: listId,
        note: Value(note),
        dueAt: Value(dueAt),
        dueHasTime: Value(dueHasTime),
        remindAt: Value(remindAt),
        sortOrder: Value(now.toDouble()),
        createdAt: now,
        updatedAt: now,
        originDevice: device,
      ),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

  Future<void> updateTask({
    required String id,
    required String title,
    required String listId,
    String? note,
    int? dueAt,
    bool dueHasTime = false,
    int? remindAt,
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
        updatedAt: Value(_nowMs()),
      ),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

  Future<void> setCompleted(Task task, bool done) async {
    final now = _nowMs();
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

  Future<void> softDelete(String id) async {
    await _db.taskDao.patch(
      id,
      TasksCompanion(deleted: const Value(true), updatedAt: Value(_nowMs())),
    );
    await _syncReminder(await _db.taskDao.findById(id));
  }

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
