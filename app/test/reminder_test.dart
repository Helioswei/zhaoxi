import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/repo/task_repository.dart';
import 'package:zhaoxi/services/reminder_scheduler.dart';

class FakeScheduler implements ReminderScheduler {
  final scheduled = <int, DateTime>{};
  final cancelled = <int>[];

  @override
  Future<bool> schedule(int id, String title, DateTime when, String taskId) async {
    scheduled[id] = when;
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
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

  int futureMs([int hours = 1]) =>
      DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch;

  test('有未来提醒的任务会排程并分配 notif_id', () async {
    await repo.createTask(
      title: '交材料',
      listId: 'list-work',
      remindAt: futureMs(),
    );
    expect(scheduler.scheduled.length, 1);
    final notifId = scheduler.scheduled.keys.single;
    expect(notifId, greaterThanOrEqualTo(1));

    final task = await db.taskDao.findById(
      (await db.taskDao.futureReminders(DateTime.now().millisecondsSinceEpoch))
          .single
          .id,
    );
    expect(task!.notifId, notifId);
  });

  test('提醒时间已过则不排程（见 02 §2.3.2）', () async {
    final past =
        DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    await repo.createTask(title: '过去的事', listId: 'list-life', remindAt: past);
    expect(scheduler.scheduled, isEmpty);
  });

  test('不经排程的任务不占用 notif_id', () async {
    await repo.createTask(title: '无提醒', listId: 'list-life');
    final task = (await db.taskDao.futureReminders(0));
    expect(task, isEmpty);
    expect(scheduler.scheduled, isEmpty);
  });

  test('完成取消通知，撤销完成重新排程', () async {
    await repo.createTask(title: '打电话', listId: 'list-life', remindAt: futureMs());
    final task = (await db.taskDao.futureReminders(
      DateTime.now().millisecondsSinceEpoch,
    ))
        .single;
    expect(scheduler.scheduled, isNotEmpty);

    await repo.setCompleted(task, true);
    expect(scheduler.scheduled, isEmpty);

    final completed = (await db.taskDao.findById(task.id))!;
    await repo.setCompleted(completed, false);
    expect(scheduler.scheduled, isNotEmpty);
  });

  test('删除取消通知，撤销删除重新排程', () async {
    await repo.createTask(title: '买菜', listId: 'list-life', remindAt: futureMs());
    final task = (await db.taskDao.futureReminders(
      DateTime.now().millisecondsSinceEpoch,
    ))
        .single;

    await repo.softDelete(task.id);
    expect(scheduler.scheduled, isEmpty);

    await repo.restore(task.id);
    expect(scheduler.scheduled, isNotEmpty);
  });

  test('rescheduleAll 重排全部未来提醒', () async {
    await repo.createTask(title: '复盘', listId: 'list-work', remindAt: futureMs(4));
    scheduler.scheduled.clear();
    await repo.rescheduleAll();
    expect(scheduler.scheduled.length, 1);
  });

  test('修改提醒时间后只保留一条排程', () async {
    await repo.createTask(title: '改时间', listId: 'list-work', remindAt: futureMs());
    final task = (await db.taskDao.futureReminders(
      DateTime.now().millisecondsSinceEpoch,
    ))
        .single;

    await repo.updateTask(
      id: task.id,
      title: '改时间',
      listId: 'list-work',
      remindAt: futureMs(5),
    );
    expect(scheduler.scheduled.length, 1);
  });
}
