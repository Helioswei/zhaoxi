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

  test('只清理超过保留期（7 天）的回收站记录', () async {
    final recent = await repo.createTask(title: '刚删的', listId: 'list-life');
    final old = await repo.createTask(title: '很久前删的', listId: 'list-life');
    await repo.softDelete(recent);
    await repo.softDelete(old);

    // 把 old 的 updatedAt 改到 8 天前（超过 7 天保留期）
    final past = DateTime.now()
        .subtract(const Duration(days: 8))
        .millisecondsSinceEpoch;
    await db.taskDao.patch(old, TasksCompanion(updatedAt: Value(past)));

    final purged = await repo.purgeOldDeleted();
    expect(purged, 1);
    expect(await db.taskDao.findById(old), isNull);
    expect(await db.taskDao.findById(recent), isNotNull);
  });

  test('全局搜索：跨视图、含已完成，标题与备注都能命中', () async {
    await repo.createTask(
      title: '交季度报告',
      note: '附预算表',
      listId: 'list-work',
      dueAt: DateTime.now()
          .add(const Duration(days: 30))
          .millisecondsSinceEpoch, // 远在「以后」，与当前视图无关
    );
    await repo.createTask(title: '买菜', listId: 'list-life');
    final doneId = await repo.createTask(title: '写周报', listId: 'list-work');
    await repo.setCompleted((await db.taskDao.findById(doneId))!, true);

    expect((await repo.search('季度').first).map((t) => t.title),
        ['交季度报告']);
    expect((await repo.search('预算').first).map((t) => t.title),
        ['交季度报告'], reason: '备注也应命中');
    expect((await repo.search('周报').first).map((t) => t.title), ['写周报'],
        reason: '已完成的也要能搜到');
    expect((await repo.search('买').first).map((t) => t.title), ['买菜']);
    expect(await repo.search('不存在的东西').first, isEmpty);
  });

  test('搜索按清单过滤（可选）', () async {
    await repo.createTask(title: '报告 A', listId: 'list-work');
    await repo.createTask(title: '报告 B', listId: 'list-life');

    expect((await repo.search('报告', listId: 'list-work').first).length, 1);
    expect((await repo.search('报告').first).length, 2);
  });
}
