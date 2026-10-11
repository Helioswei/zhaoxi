import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/tables.dart';

part 'list_dao.g.dart';

/// 内置清单的固定 id 与出厂值。
const kBuiltinLists = <({String id, String name, String color, int order})>[
  (id: 'list-work', name: '工作', color: '#3B6EA5', order: 0),
  (id: 'list-life', name: '生活', color: '#3B7A6E', order: 1),
];

/// 没有可用清单时的兜底（见 02 §2.3）。
const kFallbackListId = 'list-life';

@DriftAccessor(tables: [TaskLists])
class ListDao extends DatabaseAccessor<AppDatabase> with _$ListDaoMixin {
  ListDao(super.db);

  Stream<List<TaskList>> watchAll() {
    return (select(taskLists)
          ..where((l) => l.deleted.equals(false))
          ..orderBy([(l) => OrderingTerm(expression: l.sortOrder)]))
        .watch();
  }

  Future<List<TaskList>> getAll() =>
      (select(taskLists)..where((l) => l.deleted.equals(false))).get();

  Future<TaskList?> getById(String id) =>
      (select(taskLists)..where((l) => l.id.equals(id))).getSingleOrNull();

  Future<void> upsert(TaskListsCompanion list) =>
      into(taskLists).insertOnConflictUpdate(list);

  Future<void> patch(String id, TaskListsCompanion values) =>
      (update(taskLists)..where((l) => l.id.equals(id))).write(values);

  Future<void> softDelete(String id) => patch(
        id,
        TaskListsCompanion(
          deleted: const Value(true),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<double> nextSortOrder() async {
    final row = await (selectOnly(taskLists)
          ..addColumns([taskLists.sortOrder.max()]))
        .getSingle();
    return (row.read(taskLists.sortOrder.max()) ?? 0) + 1;
  }

  /// 全量备份用：包含软删除的行。
  Future<List<TaskList>> allForBackup() => select(taskLists).get();

  Future<void> deleteAllLists() => delete(taskLists).go();

  /// 首启补齐内置清单。**只补缺失的**，不覆盖用户改过的名字/颜色。
  Future<void> ensureBuiltins() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final b in kBuiltinLists) {
      final existing = await (select(taskLists)..where((l) => l.id.equals(b.id)))
          .getSingleOrNull();
      if (existing != null) continue;
      await into(taskLists).insert(
        TaskListsCompanion.insert(
          id: b.id,
          name: b.name,
          color: Value(b.color),
          sortOrder: Value(b.order.toDouble()),
          isBuiltin: const Value(true),
          updatedAt: now,
          originDevice: 'system',
        ),
      );
    }
  }
}
