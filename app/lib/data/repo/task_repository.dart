import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/task_filter.dart';
import '../dao/settings_dao.dart';
import '../db/database.dart';

/// 任务的读写入口。所有业务规则（时间戳、软删、ID 生成）都集中在这里。
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

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
    final now = DateTime.now().millisecondsSinceEpoch;
    final device = await ensureDeviceId();
    await _db.taskDao.upsert(
      TasksCompanion.insert(
        id: _uuid.v4(),
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
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.taskDao.patch(
      id,
      TasksCompanion(
        title: Value(title),
        listId: Value(listId),
        note: Value(note),
        dueAt: Value(dueAt),
        dueHasTime: Value(dueHasTime),
        remindAt: Value(remindAt),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> setCompleted(Task task, bool done) async {
    final now = DateTime.now().millisecondsSinceEpoch;
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
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.taskDao.patch(
      id,
      TasksCompanion(deleted: const Value(true), updatedAt: Value(now)),
    );
  }

  Future<void> restore(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.taskDao.patch(
      id,
      TasksCompanion(deleted: const Value(false), updatedAt: Value(now)),
    );
  }
}
