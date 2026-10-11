import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../dao/list_dao.dart';
import '../dao/settings_dao.dart';
import '../db/database.dart';

class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();
  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 可选色板（与 03 §6.1 的清单色一致）。
  static const palette = <String>[
    '#3B6EA5', // 工作·蓝
    '#3B7A6E', // 生活·绿
    '#8A6FB0', // 紫
    '#C0803A', // 橙
    '#B3261E', // 红
    '#2F7D8C', // 青
    '#6B7280', // 灰
  ];

  Stream<List<TaskList>> watchAll() => _db.listDao.watchAll();

  Future<List<TaskList>> getAll() => _db.listDao.getAll();

  Future<TaskList?> findById(String id) => _db.listDao.getById(id);

  Future<void> ensureBuiltins() => _db.listDao.ensureBuiltins();

  /// 新建任务时的默认清单：当前筛选为具体清单则用它，
  /// 否则取"上次使用"，再否则「生活」（见 02 §2.3）。
  Future<String> resolveDefaultListId({String? currentFilter}) async {
    if (currentFilter != null && currentFilter.isNotEmpty) return currentFilter;
    final last = await _db.settingsDao.get(SettingsKeys.lastUsedList);
    if (last != null && last.isNotEmpty) return last;
    return kFallbackListId;
  }

  Future<void> rememberLastUsedList(String listId) =>
      _db.settingsDao.set(SettingsKeys.lastUsedList, listId);

  /// 改名。内置清单也可以改（只是不能删）。
  Future<void> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _db.listDao.patch(
      id,
      TaskListsCompanion(name: Value(trimmed), updatedAt: Value(_now())),
    );
  }

  Future<void> setColor(String id, String? hex) => _db.listDao.patch(
        id,
        TaskListsCompanion(color: Value(hex), updatedAt: Value(_now())),
      );

  Future<String> addCustom({required String name, String? color}) async {
    final trimmed = name.trim();
    final id = _uuid.v4();
    final order = await _db.listDao.nextSortOrder();
    await _db.listDao.upsert(
      TaskListsCompanion.insert(
        id: id,
        name: trimmed.isEmpty ? '新清单' : trimmed,
        color: Value(color),
        sortOrder: Value(order),
        updatedAt: _now(),
        originDevice: await _deviceId(),
      ),
    );
    return id;
  }

  /// 删除自定义清单：先把任务迁到 [toListId]，再软删清单。
  Future<void> deleteWithReassign(String id, {required String toListId}) async {
    await _db.taskDao.reassignList(id, toListId);
    await _db.listDao.softDelete(id);
  }

  Future<int> countTasks(String listId) => _db.taskDao.countInList(listId);

  Future<String> _deviceId() async {
    final existing = await _db.settingsDao.get(SettingsKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = _uuid.v4();
    await _db.settingsDao.set(SettingsKeys.deviceId, id);
    return id;
  }
}
