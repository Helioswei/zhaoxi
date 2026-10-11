import 'package:drift/drift.dart';

import '../db/database.dart';

/// 备份 JSON 的读写映射（结构见 05 §六）。
///
/// 约定：**导出不含 `deviceId`**；导入**不覆盖** `device_id` / `notif_id_counter`。
const kExportFormatVersion = 1;
const kAppTag = 'zhaoxi';

Map<String, dynamic> taskToJson(Task t) => {
      'id': t.id,
      'title': t.title,
      'note': t.note,
      'listId': t.listId,
      'status': t.status,
      'dueAt': t.dueAt,
      'dueHasTime': t.dueHasTime,
      'remindAt': t.remindAt,
      'repeatRule': t.repeatRule,
      'completedCount': t.completedCount,
      'isImportant': t.isImportant,
      'sortOrder': t.sortOrder,
      'completedAt': t.completedAt,
      'createdAt': t.createdAt,
      'updatedAt': t.updatedAt,
      'deleted': t.deleted,
      'originDevice': t.originDevice,
    };

Map<String, dynamic> listToJson(TaskList l) => {
      'id': l.id,
      'name': l.name,
      'color': l.color,
      'sortOrder': l.sortOrder,
      'isBuiltin': l.isBuiltin,
      'deleted': l.deleted,
      'updatedAt': l.updatedAt,
      'originDevice': l.originDevice,
    };

int? _int(Object? v) => v is num ? v.toInt() : null;
bool _bool(Object? v, {bool fallback = false}) =>
    v is bool ? v : fallback;

TasksCompanion taskFromJson(Map<String, dynamic> j) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TasksCompanion(
    id: Value(j['id'] as String),
    title: Value((j['title'] as String?) ?? '(无标题)'),
    note: Value(j['note'] as String?),
    listId: Value((j['listId'] as String?) ?? 'list-life'),
    status: Value(_int(j['status']) ?? 0),
    dueAt: Value(_int(j['dueAt'])),
    dueHasTime: Value(_bool(j['dueHasTime'])),
    remindAt: Value(_int(j['remindAt'])),
    repeatRule: Value(j['repeatRule'] as String?),
    completedCount: Value(_int(j['completedCount']) ?? 0),
    isImportant: Value(_bool(j['isImportant'])),
    sortOrder: Value((j['sortOrder'] as num?)?.toDouble() ?? now.toDouble()),
    completedAt: Value(_int(j['completedAt'])),
    createdAt: Value(_int(j['createdAt']) ?? now),
    updatedAt: Value(_int(j['updatedAt']) ?? now),
    deleted: Value(_bool(j['deleted'])),
    originDevice: Value((j['originDevice'] as String?) ?? 'unknown'),
  );
}

TaskListsCompanion listFromJson(Map<String, dynamic> j) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TaskListsCompanion(
    id: Value(j['id'] as String),
    name: Value((j['name'] as String?) ?? '清单'),
    color: Value(j['color'] as String?),
    sortOrder: Value((j['sortOrder'] as num?)?.toDouble() ?? 0),
    isBuiltin: Value(_bool(j['isBuiltin'])),
    deleted: Value(_bool(j['deleted'])),
    updatedAt: Value(_int(j['updatedAt']) ?? now),
    originDevice: Value((j['originDevice'] as String?) ?? 'unknown'),
  );
}
