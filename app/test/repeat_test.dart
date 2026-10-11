import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/repo/task_repository.dart';
import 'package:zhaoxi/domain/repeat_rule.dart';
import 'package:zhaoxi/services/reminder_scheduler.dart';

class FakeScheduler implements ReminderScheduler {
  final scheduled = <int, DateTime>{};

  @override
  Future<bool> schedule(int id, String title, DateTime when, String taskId) async {
    scheduled[id] = when;
    return true;
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

void main() {
  late AppDatabase db;
  late FakeScheduler scheduler;
  late TaskRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.listDao.ensureBuiltins();
    scheduler = FakeScheduler();
    repo = TaskRepository(db, scheduler);
  });

  tearDown(() => db.close());

  test('重复任务完成后原地推进：dueAt 前进、计数+1、状态仍为待办', () async {
    final due = DateTime.now().subtract(const Duration(hours: 2));
    final id = await repo.createTask(
      title: '倒垃圾',
      listId: 'list-life',
      dueAt: due.millisecondsSinceEpoch,
      remindAt: due.millisecondsSinceEpoch,
      repeatRule: RepeatRule.daily().encode(),
    );

    final before = (await db.taskDao.findById(id))!;
    await repo.setCompleted(before, true);

    final after = (await db.taskDao.findById(id))!;
    expect(after.status, 0, reason: '重复任务不进已完成');
    expect(after.completedCount, 1);
    expect(after.dueAt! > due.millisecondsSinceEpoch, isTrue);
    expect(after.dueAt! > DateTime.now().millisecondsSinceEpoch, isTrue,
        reason: '应排到未来的下一次');
    expect(scheduler.scheduled, isNotEmpty, reason: '应重排下一次提醒');
  });

  test('撤销重复完成：dueAt / 计数 / 状态都回到旧值', () async {
    final due = DateTime.now().subtract(const Duration(hours: 2));
    final id = await repo.createTask(
      title: '倒垃圾',
      listId: 'list-life',
      dueAt: due.millisecondsSinceEpoch,
      repeatRule: RepeatRule.daily().encode(),
    );

    final before = (await db.taskDao.findById(id))!;
    await repo.setCompleted(before, true);
    await repo.restoreRepeatCompletion(before);

    final restored = (await db.taskDao.findById(id))!;
    expect(restored.dueAt, before.dueAt);
    expect(restored.completedCount, before.completedCount);
    expect(restored.status, before.status);
    expect(restored.repeatRule, before.repeatRule);
  });

  test('提醒相对截止的提前量会被保留', () async {
    final now = DateTime.now();
    final due = now.subtract(const Duration(hours: 1));
    final remind = due.subtract(const Duration(minutes: 30));
    final id = await repo.createTask(
      title: '周会',
      listId: 'list-work',
      dueAt: due.millisecondsSinceEpoch,
      remindAt: remind.millisecondsSinceEpoch,
      repeatRule: RepeatRule.daily().encode(),
    );

    final before = (await db.taskDao.findById(id))!;
    await repo.setCompleted(before, true);
    final after = (await db.taskDao.findById(id))!;

    expect(after.dueAt! - after.remindAt!, 30 * 60 * 1000);
  });

  test('到达 count 上限后系列结束：正常完成并清掉重复规则', () async {
    final due = DateTime.now().subtract(const Duration(hours: 1));
    final id = await repo.createTask(
      title: '连着做三次',
      listId: 'list-life',
      dueAt: due.millisecondsSinceEpoch,
      repeatRule: const RepeatRule(freq: RepeatFreq.daily, count: 1).encode(),
    );

    final before = (await db.taskDao.findById(id))!;
    await repo.setCompleted(before, true);

    final after = (await db.taskDao.findById(id))!;
    expect(after.status, 1);
    expect(after.repeatRule, isNull);
  });

  test('普通任务完成仍进入已完成', () async {
    final id = await repo.createTask(title: '买菜', listId: 'list-life');
    final task = (await db.taskDao.findById(id))!;
    await repo.setCompleted(task, true);
    expect((await db.taskDao.findById(id))!.status, 1);
  });
}
