import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../domain/day_boundary.dart';
import '../../domain/view_kind.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_pill.dart';
import '../task_edit/task_edit_sheet.dart';
import 'task_tile.dart';

class TaskListPage extends ConsumerStatefulWidget {
  const TaskListPage({super.key});

  @override
  ConsumerState<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends ConsumerState<TaskListPage> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchController.clear();
      ref.read(searchQueryProvider.notifier).clear();
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _searchFocus.requestFocus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(selectedViewProvider);
    final query = ref.watch(searchQueryProvider).trim();
    final searching = query.isNotEmpty;
    final tasksAsync = searching
        ? ref.watch(searchResultsProvider)
        : ref.watch(taskListProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            openTaskEditSheet(context),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            openTaskEditSheet(context),
        const SingleActivator(LogicalKeyboardKey.slash): _toggleSearch,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchOpen) _toggleSearch();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('朝夕'),
            actions: [
              IconButton(
                tooltip: _searchOpen ? '关闭搜索' : '搜索（/）',
                icon: Icon(_searchOpen ? Icons.close : Icons.search),
                onPressed: _toggleSearch,
              ),
              IconButton(
                tooltip: '设置',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ],
          ),
          body: Column(
            children: [
              const _ListFilterBar(),
              const _ViewBar(),
              if (_searchOpen) _searchField(),
              const Divider(height: 1),
              Expanded(
                child: tasksAsync.when(
                  data: (tasks) => _TaskListBody(
                    tasks: tasks,
                    view: view,
                    searching: searching,
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('出错了：$e')),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'add',
            tooltip: '新建任务（⌘N）',
            shape: const CircleBorder(),
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
            onPressed: () => openTaskEditSheet(context),
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索标题或备注…',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: context.colors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => ref.read(searchQueryProvider.notifier).update(v),
      ),
    );
  }
}

class _ListFilterBar extends ConsumerWidget {
  const _ListFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final selected = ref.watch(selectedListIdProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          AppPill(
            label: '全部',
            selected: selected == null,
            onTap: () => ref.read(selectedListIdProvider.notifier).select(null),
          ),
          for (final l in lists)
            AppPill(
              label: l.name,
              selected: selected == l.id,
              dotColor: listColor(l.id, l.color, context.tokens.primary),
              onTap: () =>
                  ref.read(selectedListIdProvider.notifier).select(l.id),
            ),
        ],
      ),
    );
  }
}

class _ViewBar extends ConsumerWidget {
  const _ViewBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedViewProvider);
    final config = ref.watch(viewConfigProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final v in config.visible)
            AppPill(
              dense: true,
              label: config.labelOf(v),
              selected: selected == v,
              onTap: () =>
                  ref.read(selectedViewProvider.notifier).select(v),
            ),
        ],
      ),
    );
  }
}

/// 分组头（不可拖拽）。
class _GroupHeader {
  const _GroupHeader(this.group, this.count, {this.danger = false});
  final String group;
  final int count;
  final bool danger;
}

class _TaskListBody extends ConsumerWidget {
  const _TaskListBody({
    required this.tasks,
    required this.view,
    required this.searching,
  });

  final List<Task> tasks;
  final ViewKind view;
  final bool searching;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = tasks;
    if (list.isEmpty) return _emptyState(context, searching);

    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final byId = {for (final l in lists) l.id: l};

    // 搜索结果：不分组的平铺列表
    if (searching) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 120),
        itemCount: list.length,
        itemBuilder: (_, i) => _tile(context, byId, list[i]),
      );
    }

    // 已完成：平铺，不拖拽
    if (view == ViewKind.done) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 120),
        itemCount: list.length,
        itemBuilder: (_, i) => _tile(context, byId, list[i]),
      );
    }

    final bounds = DayBounds();
    final rows = _buildRows(list, bounds);

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(top: 4, bottom: 120),
      itemCount: rows.length,
      onReorderItem: (oldIndex, newIndex) =>
          _onReorder(ref, rows, bounds, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _GroupHeader) {
          return KeyedSubtree(
            key: ValueKey('h-${row.group}'),
            child: _sectionHeader(context, '${row.group}（${row.count}）',
                danger: row.danger),
          );
        }
        final task = row as Task;
        return ReorderableDragStartListener(
          key: ValueKey('t-${task.id}'),
          index: index,
          child: _tile(context, byId, task),
        );
      },
    );
  }

  /// 按视图生成「分组头 + 任务」的扁平列表。
  List<Object> _buildRows(List<Task> list, DayBounds b) {
    final order = switch (view) {
      ViewKind.today => const ['逾期', '今天'],
      ViewKind.upcoming => const ['明天', '本周', '本月', '更远'],
      _ => const ['逾期', '今天', '明天', '本周', '本月', '更远'],
    };
    final groups = <String, List<Task>>{for (final g in order) g: []};
    for (final t in list) {
      groups[_bucketOf(t, b, view)]!.add(t);
    }
    final rows = <Object>[];
    for (final g in order) {
      final items = groups[g]!;
      if (items.isEmpty) continue;
      rows.add(_GroupHeader(g, items.length, danger: g == '逾期'));
      rows.addAll(items);
    }
    return rows;
  }

  /// 组内排序：跨组一律拒绝（列表自动回弹）。
  void _onReorder(
    WidgetRef ref,
    List<Object> rows,
    DayBounds bounds,
    int oldIndex,
    int newIndex,
  ) {
    final moved = rows[oldIndex];
    if (moved is! Task) return;
    final group = _bucketOf(moved, bounds, view);

    final without = [...rows]..removeAt(oldIndex);
    final prev = newIndex - 1 >= 0 ? without[newIndex - 1] : null;
    final next = newIndex < without.length ? without[newIndex] : null;

    bool sameGroup(Object? o) =>
        o is Task && _bucketOf(o, bounds, view) == group;

    final prevOk = prev == null ||
        sameGroup(prev) ||
        (prev is _GroupHeader && prev.group == group);
    final nextOk = next == null ||
        sameGroup(next) ||
        (next is _GroupHeader && next.group == group && newIndex == 0);
    if (!prevOk || !nextOk) return;

    ref.read(taskRepositoryProvider).reorderWithinGroup(
          movedId: moved.id,
          beforeId: prev is Task ? prev.id : null,
          afterId: next is Task ? next.id : null,
        );
  }

  String _bucketOf(Task t, DayBounds b, ViewKind v) {
    final due = t.dueAt!;
    return switch (v) {
      ViewKind.today => due < b.todayStartMs ? '逾期' : '今天',
      ViewKind.upcoming => due < b.dayAfterTomorrowStartMs
          ? '明天'
          : (due < b.nextWeekStartMs
              ? '本周'
              : (due < b.nextMonthStartMs ? '本月' : '更远')),
      _ => due < b.todayStartMs
          ? '逾期'
          : (due < b.tomorrowStartMs
              ? '今天'
              : (due < b.dayAfterTomorrowStartMs
                  ? '明天'
                  : (due < b.nextWeekStartMs
                      ? '本周'
                      : (due < b.nextMonthStartMs ? '本月' : '更远')))),
    };
  }

  Widget _tile(BuildContext context, Map<String, TaskList> byId, Task task) {
    final list = byId[task.listId];
    return TaskTile(
      task: task,
      listName: list?.name ?? '生活',
      listColorValue:
          listColor(task.listId, list?.color, context.colors.primary),
    );
  }

  Widget _sectionHeader(BuildContext context, String text,
      {bool danger = false}) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: danger ? t.danger : t.textSecondary,
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool searching) {
    if (searching) {
      return const AppEmptyState(
        emoji: '🔍',
        text: '没找到匹配的任务',
        hint: '换个关键词试试',
      );
    }
    return switch (view) {
      ViewKind.today => const AppEmptyState(
          emoji: '🍵',
          text: '今天没有安排',
          hint: '要不要记一件小事？',
        ),
      ViewKind.upcoming => const AppEmptyState(
          emoji: '🌤️',
          text: '接下来没有安排',
          hint: '未来的事都会出现在这里',
        ),
      ViewKind.done => const AppEmptyState(
          emoji: '✅',
          text: '还没有完成的任务',
          hint: '做完的事会收在这里',
        ),
      _ => const AppEmptyState(emoji: '🗒️', text: '这里还没有内容'),
    };
  }
}
