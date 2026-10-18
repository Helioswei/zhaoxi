import 'package:drift/drift.dart';

import '../../domain/task_filter.dart';
import '../../domain/view_kind.dart';
import '../db/database.dart';
import '../db/tables.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  /// 按视图 + 清单查询任务，实时流。
  ///
  /// 视图语义（见 02 §2.2）：
  /// - 今天：`due_at < 明天 00:00`（**含逾期**）
  /// - 接下来：`due_at >= 明天 00:00`
  /// - 全部：所有未完成（默认隐藏）
  /// - 已完成：`status = 1`
  Stream<List<Task>> watch(TaskFilter f) {
    final q = select(tasks)..where((t) => t.deleted.equals(false));
    final b = f.bounds;

    switch (f.view) {
      case ViewKind.today:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isNotNull() &
            t.dueAt.isSmallerThanValue(b.tomorrowStartMs));
      case ViewKind.upcoming:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isNotNull() &
            t.dueAt.isBiggerOrEqualValue(b.tomorrowStartMs));
      case ViewKind.all:
        q.where((t) => t.status.equals(0));
      case ViewKind.done:
        q.where((t) => t.status.equals(1));
    }

    if (f.listId != null) {
      final listId = f.listId!;
      q.where((t) => t.listId.equals(listId));
    }

    switch (f.view) {
      case ViewKind.done:
        q.orderBy([(t) => OrderingTerm.desc(t.completedAt)]);
        q.limit(500);
      case ViewKind.all:
        q.orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
      case ViewKind.today:
      case ViewKind.upcoming:
        q.orderBy([
          (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
          (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        ]);
    }

    return q.watch();
  }

  Future<void> upsert(TasksCompanion task) =>
      into(tasks).insertOnConflictUpdate(task);

  /// 全量备份：包含软删除的行（保持软删状态）。
  Future<List<Task>> allForBackup() => select(tasks).get();

  /// 区间内已完成（按 completedAt）。
  Future<List<Task>> completedBetween(int from, int to) {
    return (select(tasks)
          ..where((t) =>
              t.deleted.equals(false) &
              t.status.equals(1) &
              t.completedAt.isNotNull() &
              t.completedAt.isBiggerOrEqualValue(from) &
              t.completedAt.isSmallerThanValue(to)))
        .get();
  }

  /// 区间内未完成（按 dueAt）。
  Future<List<Task>> openDueBetween(int from, int to) {
    return (select(tasks)
          ..where((t) =>
              t.deleted.equals(false) &
              t.status.equals(0) &
              t.dueAt.isNotNull() &
              t.dueAt.isBiggerOrEqualValue(from) &
              t.dueAt.isSmallerThanValue(to)))
        .get();
  }

  /// 区间内被删除的任务（按删除时间 = updatedAt）。
  Future<List<Task>> deletedBetween(int from, int to) {
    return (select(tasks)
          ..where((t) =>
              t.deleted.equals(true) &
              t.updatedAt.isBiggerOrEqualValue(from) &
              t.updatedAt.isSmallerThanValue(to))
          ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<void> deleteAllTasks() => delete(tasks).go();

  // ------------------------------------------------------------ 回收站

  /// 回收站：查看已（软）删除的任务，最近的在前。
  Stream<List<Task>> watchDeleted() {
    return (select(tasks)
          ..where((t) => t.deleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// 全局搜索：标题或备注包含关键词（不分视图、含已完成）。
  Stream<List<Task>> watchSearch(String query, {String? listId}) {
    final q = select(tasks)..where((t) => t.deleted.equals(false));
    final pattern = '%${query.replaceAll('%', r'\%').replaceAll('_', r'\_')}%';
    q.where((t) => t.title.like(pattern) | t.note.like(pattern));
    if (listId != null) q.where((t) => t.listId.equals(listId));
    q.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    q.limit(200);
    return q.watch();
  }

  /// 从回收站彻底删除（物理删除，不可恢复）。
  Future<void> hardDelete(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<void> hardDeleteAll() =>
      (delete(tasks)..where((t) => t.deleted.equals(true))).go();

  /// 清理 [beforeMs] 之前删除的记录。
  Future<int> purgeDeletedOlderThan(int beforeMs) async {
    return (delete(tasks)
          ..where((t) =>
              t.deleted.equals(true) & t.updatedAt.isSmallerThanValue(beforeMs)))
        .go();
  }

  // ------------------------------------------------------------ 排序 / 清单

  /// 新建任务排在最后：取当前最大值 + 一个步长。
  Future<double> nextSortOrder() async {
    final row = await (selectOnly(tasks)
          ..addColumns([tasks.sortOrder.max()]))
        .getSingle();
    final max = row.read(tasks.sortOrder.max()) ?? 0;
    return max + 1024;
  }

  Future<List<Task>> allOrderedBySort() =>
      (select(tasks)..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

  Future<void> patchSortOrder(String id, double value) => patch(
        id,
        TasksCompanion(
          sortOrder: Value(value),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<void> applySortOrders(Map<String, double> values) async {
    await batch((b) {
      for (final entry in values.entries) {
        b.update(
          tasks,
          TasksCompanion(sortOrder: Value(entry.value)),
          where: (t) => t.id.equals(entry.key),
        );
      }
    });
  }

  /// 删除清单前：把该清单下的任务整体改到另一个清单。
  Future<void> reassignList(String fromListId, String toListId) async {
    await (update(tasks)..where((t) => t.listId.equals(fromListId))).write(
      TasksCompanion(
        listId: Value(toListId),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// 某清单下的任务数（用于删除清单时的提示）。
  Future<int> countInList(String listId) async {
    final count = countAll();
    final row = await (selectOnly(tasks)
          ..addColumns([count])
          ..where(tasks.listId.equals(listId) & tasks.deleted.equals(false)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  // ---------------------------------------------------------------- 基础

  Future<void> patch(String id, TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(task);

  Future<Task?> findById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// 启动时用于重排：所有尚未完成、且提醒时间在未来的任务。
  Future<List<Task>> futureReminders(int nowMs) {
    return (select(tasks)
          ..where((t) =>
              t.deleted.equals(false) &
              t.status.equals(0) &
              t.remindAt.isNotNull() &
              t.remindAt.isBiggerThanValue(nowMs)))
        .get();
  }
}
