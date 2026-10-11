import 'package:drift/drift.dart';

import '../../domain/task_filter.dart';
import '../../domain/view_kind.dart';
import '../db/database.dart';
import '../db/tables.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  /// 按"时间视图 + 清单"查询任务，实时流。
  Stream<List<Task>> watch(TaskFilter f) {
    final q = select(tasks)..where((t) => t.deleted.equals(false));
    final b = f.bounds;

    switch (f.view) {
      case ViewKind.undated:
        q.where((t) => t.status.equals(0) & t.dueAt.isNull());
      case ViewKind.today:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isNotNull() &
            t.dueAt.isSmallerThanValue(b.tomorrowStartMs));
      case ViewKind.tomorrow:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isBiggerOrEqualValue(b.tomorrowStartMs) &
            t.dueAt.isSmallerThanValue(b.dayAfterTomorrowStartMs));
      case ViewKind.week:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isBiggerOrEqualValue(b.weekStartMs) &
            t.dueAt.isSmallerThanValue(b.nextWeekStartMs));
      case ViewKind.month:
        q.where((t) =>
            t.status.equals(0) &
            t.dueAt.isBiggerOrEqualValue(b.monthStartMs) &
            t.dueAt.isSmallerThanValue(b.nextMonthStartMs));
      case ViewKind.later:
        q.where((t) =>
            t.status.equals(0) & t.dueAt.isBiggerOrEqualValue(b.nextMonthStartMs));
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
      case ViewKind.undated:
        q.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
      default:
        q.orderBy([
          (t) => OrderingTerm(expression: t.dueAt, mode: OrderingMode.asc),
          (t) => OrderingTerm(expression: t.sortOrder, mode: OrderingMode.asc),
        ]);
    }

    return q.watch();
  }

  /// 未完成、无日期（「待定」）的条数——用于「今天」页顶部汇总。
  Stream<int> watchUndatedCount({String? listId}) {
    final count = countAll();
    final q = selectOnly(tasks)
      ..addColumns([count])
      ..where(tasks.deleted.equals(false) &
          tasks.status.equals(0) &
          tasks.dueAt.isNull());
    if (listId != null) {
      q.where(tasks.listId.equals(listId));
    }
    return q.map((row) => row.read(count) ?? 0).watchSingle();
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

  Future<void> deleteAllTasks() => delete(tasks).go();

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

  Future<void> patch(String id, TasksCompanion task) =>
      (update(tasks)..where((t) => t.id.equals(id))).write(task);

  Future<Task?> findById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
}
