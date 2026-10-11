import 'dart:convert';

import '../data/json/backup_json.dart';
import '../data/db/database.dart';

class ImportResult {
  const ImportResult({
    required this.tasksImported,
    required this.tasksSkipped,
    required this.listsImported,
    required this.overwrite,
  });

  final int tasksImported;
  final int tasksSkipped;
  final int listsImported;
  final bool overwrite;

  String get summary => overwrite
      ? '已覆盖导入 $tasksImported 条'
      : '已导入 $tasksImported 条，跳过 $tasksSkipped 条（本地较新）';
}

class ImportException implements Exception {
  ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 导入备份 JSON。合并模式按 `id` + `updatedAt` 取较新；
/// **永不触碰 `settings`**（`device_id` / `notif_id_counter` / 视图配置）。
class ImportService {
  ImportService(this._db);

  final AppDatabase _db;

  Future<ImportResult> importJson(
    String content, {
    required bool overwrite,
  }) async {
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      throw ImportException('这个文件不是本 App 的备份');
    }

    if (root['app'] != kAppTag) {
      throw ImportException('这个文件不是朝夕的备份');
    }
    final version = (root['exportFormatVersion'] as num?)?.toInt() ?? 0;
    if (version > kExportFormatVersion) {
      throw ImportException('备份来自更新版本，无法导入');
    }
    // version < kExportFormatVersion 时在此逐级升级（当前只有 v1）。

    final rawTasks = (root['tasks'] as List?) ?? const [];
    final rawLists = (root['lists'] as List?) ?? const [];

    final taskMaps = <Map<String, dynamic>>[
      for (final t in rawTasks)
        if (t is Map) Map<String, dynamic>.from(t),
    ];
    final listMaps = <Map<String, dynamic>>[
      for (final l in rawLists)
        if (l is Map) Map<String, dynamic>.from(l),
    ];

    // 覆盖模式：lists 从同一文件重建，"缺清单"只可能是文件损坏 → 拒绝。
    if (overwrite) {
      final ids = {for (final l in listMaps) l['id'] as String?};
      for (final t in taskMaps) {
        final listId = t['listId'] as String?;
        if (listId != null && !ids.contains(listId)) {
          throw ImportException('备份文件损坏：任务引用了不存在的清单');
        }
      }
      // 先取消全部通知，避免"幽灵通知"指向已被替换的任务。
      await _db.taskDao.deleteAllTasks();
      await _db.listDao.deleteAllLists();
    }

    var listsImported = 0;
    for (final j in listMaps) {
      final id = j['id'] as String?;
      if (id == null) continue;
      if (overwrite) {
        await _db.listDao.upsert(listFromJson(j));
        listsImported++;
        continue;
      }
      final existing = await _db.listDao.getById(id);
      final incomingUpdated = (j['updatedAt'] as num?)?.toInt() ?? 0;
      if (existing != null && existing.updatedAt >= incomingUpdated) continue;
      await _db.listDao.upsert(listFromJson(j));
      listsImported++;
    }

    var imported = 0;
    var skipped = 0;
    for (final j in taskMaps) {
      final id = j['id'] as String?;
      if (id == null) continue;

      // 合并且本地较新 → 跳过。
      if (!overwrite) {
        final existing = await _db.taskDao.findById(id);
        final incomingUpdated = (j['updatedAt'] as num?)?.toInt() ?? 0;
        if (existing != null && existing.updatedAt >= incomingUpdated) {
          skipped++;
          continue;
        }
      }

      await _ensureListExists(j['listId'] as String?);
      await _db.taskDao.upsert(taskFromJson(j));
      imported++;
    }

    return ImportResult(
      tasksImported: imported,
      tasksSkipped: skipped,
      listsImported: listsImported,
      overwrite: overwrite,
    );
  }

  /// 合并模式：文件里没带清单定义时自动补一个，保证引用完整。
  Future<void> _ensureListExists(String? listId) async {
    if (listId == null || listId.isEmpty) return;
    final existing = await _db.listDao.getById(listId);
    if (existing != null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.listDao.upsert(
      TaskListsCompanion.insert(
        id: listId,
        name: listId == 'list-work' ? '工作' : (listId == 'list-life' ? '生活' : listId),
        updatedAt: now,
        originDevice: 'import',
      ),
    );
  }
}
