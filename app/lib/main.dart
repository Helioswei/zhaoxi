import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/repo/task_repository.dart';
import 'features/task_edit/task_edit_sheet.dart';
import 'providers/app_providers.dart';
import 'services/backup_service.dart';
import 'services/export_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.open();
  // 首启补齐内置清单（工作 / 生活），只补缺失的，不覆盖用户改动。
  await db.listDao.ensureBuiltins();

  final notifications = NotificationService.instance;
  await notifications.init();

  // 启动时重排全部未来提醒（应对重启 / 时区变化）。
  await TaskRepository(db, notifications).rescheduleAll();

  // 每天首次启动自动备份一份全量 JSON（失败不阻塞启动）。
  try {
    await BackupService(db, ExportService(db)).runIfNeeded();
  } catch (_) {
    // 备份失败不影响使用，用户仍可手动导出
  }

  // 回收站只保留 7 天，超期自动清理。
  try {
    await TaskRepository(db, notifications).purgeOldDeleted();
  } catch (_) {
    // 清理失败不影响启动
  }

  notifications.onTaskTapped = (taskId) => _openTask(db, taskId);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        reminderSchedulerProvider.overrideWithValue(notifications),
      ],
      child: const ZhaoxiApp(),
    ),
  );

  // 由通知冷启动的情况。
  final launchTaskId = await notifications.launchTaskId();
  if (launchTaskId != null) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _openTask(db, launchTaskId));
  }
}

Future<void> _openTask(AppDatabase db, String taskId) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;
  final task = await db.taskDao.findById(taskId);
  if (task == null) return;
  if (!context.mounted) return;
  await openTaskEditSheet(context, task: task);
}
