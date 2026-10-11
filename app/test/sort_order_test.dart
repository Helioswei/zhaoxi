import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/repo/task_repository.dart';
import 'package:zhaoxi/domain/sort_order.dart';
import 'package:zhaoxi/services/reminder_scheduler.dart';

void main() {
  group('排序值数学', () {
    test('两侧都有 → 取中点', () {
      expect(sortOrderBetween(1024, 2048), 1536);
    });

    test('只有一侧 → 加减一个步长', () {
      expect(sortOrderBetween(null, 2048), 1024);
      expect(sortOrderBetween(1024, null), 2048);
    });

    test('都没有 → null（保持原值）', () {
      expect(sortOrderBetween(null, null), isNull);
    });

    test('间距过小才需要整表重排', () {
      expect(needsRenormalize(1024, 2048), isFalse);
      expect(needsRenormalize(1.0, 1.0 + 1e-9), isTrue);
      expect(needsRenormalize(null, 1), isFalse);
    });

    test('重排按 1024 步长重新编号', () {
      expect(renormalized(['a', 'b', 'c']), {'a': 1024, 'b': 2048, 'c': 3072});
    });
  });

  group('组内拖拽（仓储层）', () {
    late AppDatabase db;
    late TaskRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.listDao.ensureBuiltins();
      repo = TaskRepository(db, const NoopReminderScheduler());
    });

    tearDown(() => db.close());

    Future<List<String>> order() async =>
        (await db.taskDao.allOrderedBySort()).map((t) => t.title).toList();

    test('插到某条之前', () async {
      await repo.createTask(title: 'a', listId: 'list-life');
      await repo.createTask(title: 'b', listId: 'list-life');
      final c = await repo.createTask(title: 'c', listId: 'list-life');
      expect(await order(), ['a', 'b', 'c']);

      final a = (await db.taskDao.allOrderedBySort()).first;
      await repo.reorderWithinGroup(movedId: c, beforeId: null, afterId: a.id);
      expect(await order(), ['c', 'a', 'b']);
    });

    test('插到某条之后', () async {
      final a = await repo.createTask(title: 'a', listId: 'list-life');
      await repo.createTask(title: 'b', listId: 'list-life');
      expect(await order(), ['a', 'b']);

      await repo.reorderWithinGroup(movedId: a, beforeId: a, afterId: null);
      // beforeId == movedId 时不改变位置（防御）
      expect(await order(), ['a', 'b']);
    });

    test('相邻值太小会触发整表重排', () async {
      final a = await repo.createTask(title: 'a', listId: 'list-life');
      final b = await repo.createTask(title: 'b', listId: 'list-life');
      final c = await repo.createTask(title: 'c', listId: 'list-life');

      // 人为制造几乎相等的相邻值（a 与 c ）
      await db.taskDao.patchSortOrder(a, 1000.0);
      await db.taskDao.patchSortOrder(c, 1000.0 + 1e-9);

      // 把 b 插到 a 与 c 之间 → 间距过小 → 先整表重排再插入
      await repo.reorderWithinGroup(movedId: b, beforeId: a, afterId: c);

      final ordered = await db.taskDao.allOrderedBySort();
      expect(ordered.map((t) => t.title).toList(), ['a', 'b', 'c']);
      expect(ordered[0].sortOrder, kSortStep);
      expect(ordered[1].sortOrder, kSortStep * 1.5);
      expect(ordered[2].sortOrder, kSortStep * 2);
    });
  });
}
