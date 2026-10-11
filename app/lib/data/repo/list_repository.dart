import '../dao/list_dao.dart';
import '../dao/settings_dao.dart';
import '../db/database.dart';

class ListRepository {
  ListRepository(this._db);

  final AppDatabase _db;

  Stream<List<TaskList>> watchAll() => _db.listDao.watchAll();

  Future<List<TaskList>> getAll() => _db.listDao.getAll();

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
}
