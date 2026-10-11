import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/repo/list_repository.dart';
import 'package:zhaoxi/data/repo/task_repository.dart';
import 'package:zhaoxi/services/reminder_scheduler.dart';

void main() {
  late AppDatabase db;
  late ListRepository lists;
  late TaskRepository tasks;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.listDao.ensureBuiltins();
    lists = ListRepository(db);
    tasks = TaskRepository(db, const NoopReminderScheduler());
  });

  tearDown(() => db.close());

  test('内置清单：可改名、可改色', () async {
    await lists.rename('list-work', '公司');
    await lists.setColor('list-work', '#8A6FB0');

    final work = await lists.findById('list-work');
    expect(work!.name, '公司');
    expect(work.color, '#8A6FB0');
    expect(work.isBuiltin, isTrue);
  });

  test('改名忽略空白', () async {
    await lists.rename('list-life', '   ');
    expect((await lists.findById('list-life'))!.name, '生活');
  });

  test('可以新增自定义清单', () async {
    final id = await lists.addCustom(name: '买菜', color: '#C0803A');
    final list = await lists.findById(id);
    expect(list!.name, '买菜');
    expect(list.isBuiltin, isFalse);
    expect((await lists.getAll()).length, 3);
  });

  test('删除自定义清单：任务先迁移到目标清单', () async {
    final temp = await lists.addCustom(name: '临时');
    await tasks.createTask(title: 'a', listId: temp);
    await tasks.createTask(title: 'b', listId: temp);
    expect(await lists.countTasks(temp), 2);

    await lists.deleteWithReassign(temp, toListId: 'list-life');

    // 软删：getById 还能查到，但 deleted=true，列表里不再出现
    expect((await lists.findById(temp))!.deleted, isTrue);
    expect((await lists.getAll()).map((l) => l.id), isNot(contains(temp)));
    expect(await lists.countTasks(temp), 0);
    expect(await lists.countTasks('list-life'), 2);
  });

  test('内置清单不会因为「删除」而消失（UI 层拦截，这里验证数据仍在）', () async {
    // 内置清单不允许删除：仓储层没有删除入口，UI 也不显示删除项。
    expect((await lists.findById('list-work'))!.isBuiltin, isTrue);
    expect((await lists.getAll()).map((l) => l.id),
        containsAll(['list-work', 'list-life']));
  });
}
