import 'package:drift/drift.dart';

/// 清单（工作 / 生活 / 自定义）。
///
/// 内置清单使用**固定字符串 id**（`list-work` / `list-life`，非 UUID），
/// 这是有意为之：跨设备合并时"工作/生活"才能对上；自定义清单用 UUID。
class TaskLists extends Table {
  @override
  String get tableName => 'lists';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  IntColumn get updatedAt => integer()();
  TextColumn get originDevice => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 任务。
///
/// 关键约定：
/// - `dueAt == null` → 「待定」视图（没写时间的）。
/// - `dueAt != null` 时 `dueHasTime` 才有意义；`(due_has_time=1, due_at=null)` 非法。
/// - 软删除 `deleted`；`updatedAt` / `originDevice` 为将来同步预留。
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().nullable()();
  TextColumn get listId => text()();

  /// 0 = 待办，1 = 已完成。
  IntColumn get status => integer().withDefault(const Constant(0))();

  IntColumn get dueAt => integer().nullable()();
  BoolColumn get dueHasTime => boolean().withDefault(const Constant(false))();
  IntColumn get remindAt => integer().nullable()();
  IntColumn get notifId => integer().nullable()();
  TextColumn get repeatRule => text().nullable()();
  IntColumn get completedCount => integer().withDefault(const Constant(0))();
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();
  RealColumn get sortOrder => real().withDefault(const Constant(0.0))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  TextColumn get originDevice => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 键值配置表 `settings`。
class SettingsEntries extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
