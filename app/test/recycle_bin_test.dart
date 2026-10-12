import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/repo/task_repository.dart';
import 'package:zhaoxi/services/reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.listDao.ensureBuiltins();
    repo = TaskRepository(db, const NoopReminderScheduler());
  });

  tearDown(() => db.close());

  test('删除后进回收站，可恢复', () async {
    final id = await repo.createTask(title: '买菜', listId: 'list-life');
    await repo.softDelete(id);

    var deleted = await db.taskDao.watchDeleted().first;
    expect(deleted.map((t) => t.title), ['买菜']);
    expect((await db.taskDao.findById(id))!.deleted, isTrue);

    await repo.restore(id);
    expect(await db.taskDao.watchDeleted().first, isEmpty);
    expect((await db.taskDao.findById(id))!.deleted, isFalse);
  });

  test('彻底删除后回收站里也没有了', () async {
    final id = await repo.createTask(title: '买菜', listId: 'list-life');
    await repo.softDelete(id);
    await repo.hardDelete(id);

    expect(await db.taskDao.findById(id), isNull);
    expect(await db.taskDao.watchDeleted().first, isEmpty);
  });

  test('清空回收站只删已删除的，不影响正常任务', () async {
    final a = await repo.createTask(title: '正常的', listId: 'list-life');
    final b = await repo.createTask(title: '删掉的', listId: 'list-life');
    await repo.softDelete(b);

    await repo.hardDeleteAll();

    expect(await db.taskDao.findById(a), isNotNull);
    expect(await db.taskDao.findById(b), isNull);
    expect(await db.taskDao.watchDeleted().first, isEmpty);
  });

  test('只清理 30 天前删除的记录', () async {
    final recent = await repo.createTask(title: '刚删的', listId: 'list-life');
    final old = await repo.createTask(title: '很久前删的', listId: 'list-life');
    await repo.softDelete(recent);
    await repo.softDelete(old);

    // 把 old 的 updatedAt 改到 40 天前
    final past = DateTime.now()
        .subtract(const Duration(days: 40))
        .millisecondsSinceEpoch;
    await db.taskDao.patch(
      old,
      TasksCompanion(updatedAt: Value(past)),
    );

    final purged = await repo.purgeOldDeleted();
    expect(purged, 1);
    expect(await db.taskDao.findById(old), isNull);
    expect(await db.taskDao.findById(recent), isNotNull);
  });
}
