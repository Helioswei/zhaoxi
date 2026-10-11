import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dao/settings_dao.dart';
import '../data/db/database.dart';
import '../data/repo/list_repository.dart';
import '../data/repo/task_repository.dart';
import '../domain/day_boundary.dart';
import '../domain/task_filter.dart';
import '../domain/view_kind.dart';
import '../services/reminder_scheduler.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';

/// 数据库实例。main() 里会在 `ProviderScope.overrides` 注入已初始化的实例。
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(databaseProvider),
    ref.watch(reminderSchedulerProvider),
  ),
);

/// 提醒排程实现。main() 里会覆盖成真实的 NotificationService。
final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => const NoopReminderScheduler(),
);

final listRepositoryProvider = Provider<ListRepository>(
  (ref) => ListRepository(ref.watch(databaseProvider)),
);

/// 当前选中的时间视图（默认「今天」）。
class SelectedViewNotifier extends Notifier<ViewKind> {
  @override
  ViewKind build() => ViewKind.today;

  void select(ViewKind view) => state = view;
}

final selectedViewProvider =
    NotifierProvider<SelectedViewNotifier, ViewKind>(SelectedViewNotifier.new);

/// 当前清单筛选；null = 全部清单。
class SelectedListNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? listId) => state = listId;
}

final selectedListIdProvider =
    NotifierProvider<SelectedListNotifier, String?>(SelectedListNotifier.new);

/// 当前视图 + 清单下的任务列表。
final taskListProvider = StreamProvider<List<Task>>((ref) {
  final view = ref.watch(selectedViewProvider);
  final listId = ref.watch(selectedListIdProvider);
  return ref.watch(taskRepositoryProvider).watch(
        TaskFilter(view: view, bounds: DayBounds(), listId: listId),
      );
});

/// 「今天」页顶部用来提示"还有 N 件没定时间"。
final undatedCountProvider = StreamProvider<int>((ref) {
  final listId = ref.watch(selectedListIdProvider);
  return ref.watch(taskRepositoryProvider).watchUndatedCount(listId: listId);
});

final listsProvider = StreamProvider<List<TaskList>>(
  (ref) => ref.watch(listRepositoryProvider).watchAll(),
);

/// 默认提醒提前量（分钟，0/5/15/30）。
class RemindOffsetNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    final raw = await ref
        .read(databaseProvider)
        .settingsDao
        .get(SettingsKeys.defaultRemindOffset);
    final minutes = int.tryParse(raw ?? '') ?? 0;
    if (minutes != state) state = minutes;
  }

  Future<void> select(int minutes) async {
    state = minutes;
    await ref
        .read(databaseProvider)
        .settingsDao
        .set(SettingsKeys.defaultRemindOffset, '$minutes');
  }
}

final remindOffsetProvider =
    NotifierProvider<RemindOffsetNotifier, int>(RemindOffsetNotifier.new);

final exportServiceProvider = Provider<ExportService>(
  (ref) => ExportService(ref.watch(databaseProvider)),
);

final importServiceProvider = Provider<ImportService>(
  (ref) => ImportService(ref.watch(databaseProvider)),
);
