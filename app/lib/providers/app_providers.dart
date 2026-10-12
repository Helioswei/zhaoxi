import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dao/settings_dao.dart';
import '../data/db/database.dart';
import '../data/repo/list_repository.dart';
import '../data/repo/task_repository.dart';
import '../domain/day_boundary.dart';
import '../domain/task_filter.dart';
import '../domain/view_config.dart';
import '../domain/view_kind.dart';
import '../services/reminder_scheduler.dart';
import '../services/export_service.dart';
import '../services/import_service.dart';
import '../services/backup_service.dart';
import '../ui/theme/app_style.dart';

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

/// 回收站（软删除的任务）。
final deletedTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.watch(taskRepositoryProvider).watchDeleted(),
);

/// 全局搜索结果（标题 / 备注）。关键词为空时返回空列表。
final searchResultsProvider = StreamProvider<List<Task>>((ref) {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) return Stream.value(const <Task>[]);
  final listId = ref.watch(selectedListIdProvider);
  return ref.watch(taskRepositoryProvider).search(query, listId: listId);
});

/// 默认提醒提前量（分钟，0/5/15/30）。
class RemindOffsetNotifier extends Notifier<int> {
  @override
  int build() {
    _load();
    return 0;
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(databaseProvider)
          .settingsDao
          .get(SettingsKeys.defaultRemindOffset);
      final minutes = int.tryParse(raw ?? '') ?? 0;
      if (minutes != state) state = minutes;
    } catch (_) {
      // 读不到就用默认
    }
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

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    ref.watch(databaseProvider),
    ref.watch(exportServiceProvider),
  ),
);

// --------------------------------------------------------------- 外观 / 视图

/// 主题：跟随系统 / 浅色 / 深色。
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final raw = await ref
          .read(databaseProvider)
          .settingsDao
          .get(SettingsKeys.themeMode);
      final mode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      if (mode != state) state = mode;
    } catch (_) {
      // 读不到设置就用默认（例如测试环境）
    }
  }

  Future<void> select(ThemeMode mode) async {
    state = mode;
    await ref
        .read(databaseProvider)
        .settingsDao
        .set(SettingsKeys.themeMode, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// 视图的用户配置（顺序 / 隐藏 / 重命名）。
class ViewConfigNotifier extends Notifier<ViewConfig> {
  @override
  ViewConfig build() {
    _load();
    return ViewConfig.defaults();
  }

  Future<void> _load() async {
    try {
      final dao = ref.read(databaseProvider).settingsDao;
      state = ViewConfig.decode(
        orderJson: await dao.get(SettingsKeys.viewOrder),
        hiddenJson: await dao.get(SettingsKeys.viewHidden),
        labelsJson: await dao.get(SettingsKeys.viewLabels),
      );
    } catch (_) {
      // 读不到就用默认视图配置
    }
  }

  Future<void> _persist(ViewConfig config) async {
    final dao = ref.read(databaseProvider).settingsDao;
    await dao.set(SettingsKeys.viewOrder, config.encodeOrder());
    await dao.set(SettingsKeys.viewHidden, config.encodeHidden());
    await dao.set(SettingsKeys.viewLabels, config.encodeLabels());
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final order = [...state.order];
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    final next = state.copyWith(order: order);
    state = next;
    await _persist(next);
  }

  Future<void> setHidden(ViewKind view, bool hidden) async {
    if (hidden && !view.canHide) return; // 锁定项
    final set = {...state.hidden};
    hidden ? set.add(view) : set.remove(view);
    final next = state.copyWith(hidden: set);
    state = next;
    await _persist(next);
  }

  Future<void> rename(ViewKind view, String? label) async {
    final labels = {...state.labels};
    final trimmed = label?.trim() ?? '';
    if (trimmed.isEmpty) {
      labels.remove(view);
    } else {
      labels[view] = trimmed;
    }
    final next = state.copyWith(labels: labels);
    state = next;
    await _persist(next);
  }
}

final viewConfigProvider =
    NotifierProvider<ViewConfigNotifier, ViewConfig>(ViewConfigNotifier.new);

/// 列表内搜索关键词（M4）。
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;

  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// 字号：`normal` / `large`（无障碍用，见 02 §2.7）。
class FontScaleNotifier extends Notifier<String> {
  @override
  String build() {
    _load();
    return 'normal';
  }

  Future<void> _load() async {
    try {
      final raw =
          await ref.read(databaseProvider).settingsDao.get(SettingsKeys.fontScale);
      if (raw == 'large' && state != 'large') state = 'large';
    } catch (_) {
      // 用默认
    }
  }

  Future<void> select(String value) async {
    state = value;
    await ref
        .read(databaseProvider)
        .settingsDao
        .set(SettingsKeys.fontScale, value);
  }
}

final fontScaleProvider =
    NotifierProvider<FontScaleNotifier, String>(FontScaleNotifier.new);

/// 视觉风格：清爽 / 温润 / 纸感（可实时切换对比）。
class StyleNotifier extends Notifier<AppStyleId> {
  @override
  AppStyleId build() {
    _load();
    return AppStyleId.warm; // 默认风格（用户选定）
  }

  Future<void> _load() async {
    try {
      final raw =
          await ref.read(databaseProvider).settingsDao.get(SettingsKeys.style);
      final style = AppStyleId.fromId(raw);
      if (style != state) state = style;
    } catch (_) {
      // 用默认
    }
  }

  Future<void> select(AppStyleId style) async {
    state = style;
    await ref
        .read(databaseProvider)
        .settingsDao
        .set(SettingsKeys.style, style.id);
  }
}

final styleProvider =
    NotifierProvider<StyleNotifier, AppStyleId>(StyleNotifier.new);
