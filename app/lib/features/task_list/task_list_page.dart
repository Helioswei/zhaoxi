import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../domain/day_boundary.dart';
import '../../domain/view_kind.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../quick_voice/quick_voice_button.dart';
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
    final tasksAsync = ref.watch(taskListProvider);

    // 桌面端快捷键（Android 上无键盘，不触发）。
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
              if (view == ViewKind.today && !_searchOpen) const _UndatedBanner(),
              const Divider(height: 1),
              Expanded(
                child: tasksAsync.when(
                  data: (tasks) => _TaskListBody(tasks: tasks, view: view),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('出错了：$e')),
                ),
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const QuickVoiceButton(),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'add',
                tooltip: '新建任务（⌘N）',
                shape: const CircleBorder(),
                backgroundColor: context.colors.primary,
                foregroundColor: Colors.white,
                onPressed: () => openTaskEditSheet(context),
                child: const Icon(Icons.add),
              ),
            ],
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
          _chip(
            context,
            label: '全部',
            selected: selected == null,
            onTap: () => ref.read(selectedListIdProvider.notifier).select(null),
          ),
          for (final l in lists)
            _chip(
              context,
              label: l.name,
              selected: selected == l.id,
              color: listColor(l.id, l.color, context.colors.primary),
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
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(config.labelOf(v)),
                selected: selected == v,
                onSelected: (_) =>
                    ref.read(selectedViewProvider.notifier).select(v),
              ),
            ),
        ],
      ),
    );
  }
}

class _UndatedBanner extends ConsumerWidget {
  const _UndatedBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(undatedCountProvider).value ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return InkWell(
      onTap: () =>
          ref.read(selectedViewProvider.notifier).select(ViewKind.undated),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                size: 18, color: context.colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              '还有 $count 件没定时间',
              style:
                  TextStyle(fontSize: 14, color: context.colors.onSurfaceVariant),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 20, color: context.colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// 「全部」视图里的分组头（不可拖拽）。
class _GroupHeader {
  const _GroupHeader(this.group, this.count);
  final String group;
  final int count;
}

class _TaskListBody extends ConsumerWidget {
  const _TaskListBody({required this.tasks, required this.view});

  final List<Task> tasks;
  final ViewKind view;

  static const _bucketOrder = ['逾期', '今天', '明天', '本周', '本月', '以后', '待定'];

  List<Task> _filtered(WidgetRef ref) {
    final query = ref.watch(searchQueryProvider).trim().toLowerCase();
    if (query.isEmpty) return tasks;
    return tasks
        .where((t) =>
            t.title.toLowerCase().contains(query) ||
            (t.note ?? '').toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = _filtered(ref);
    final searching = ref.watch(searchQueryProvider).trim().isNotEmpty;

    if (list.isEmpty) return _emptyState(context, searching);

    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final byId = {for (final l in lists) l.id: l};

    if (view != ViewKind.all || searching) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _tile(context, byId, list[i]),
      );
    }

    // 「全部」：按时间分组（每条只进第一个匹配的组），组内可拖拽排序。
    final bounds = DayBounds();
    final groups = <String, List<Task>>{for (final b in _bucketOrder) b: []};
    for (final t in list) {
      groups[_bucketOf(t, bounds)]!.add(t);
    }
    final rows = <Object>[];
    for (final b in _bucketOrder) {
      final items = groups[b]!;
      if (items.isEmpty) continue;
      rows.add(_GroupHeader(b, items.length));
      rows.addAll(items);
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: rows.length,
      onReorderItem: (oldIndex, newIndex) =>
          _onReorder(ref, rows, bounds, oldIndex, newIndex),
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is _GroupHeader) {
          return KeyedSubtree(
            key: ValueKey('h-${row.group}'),
            child: _sectionHeader(context, '${row.group}（${row.count}）'),
          );
        }
        final task = row as Task;
        return ReorderableDragStartListener(
          key: ValueKey('t-${task.id}'),
          index: index,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tile(context, byId, task),
              const Divider(height: 1),
            ],
          ),
        );
      },
    );
  }

  /// 组内排序：跨组一律拒绝（列表会自动回弹）。
  void _onReorder(
    WidgetRef ref,
    List<Object> rows,
    DayBounds bounds,
    int oldIndex,
    int newIndex,
  ) {
    final moved = rows[oldIndex];
    if (moved is! Task) return;
    final group = _bucketOf(moved, bounds);

    final without = [...rows]..removeAt(oldIndex);
    final prev = newIndex - 1 >= 0 ? without[newIndex - 1] : null;
    final next = newIndex < without.length ? without[newIndex] : null;

    bool sameGroup(Object? o) =>
        o is Task && _bucketOf(o, bounds) == group;

    final prevOk = prev == null ||
        sameGroup(prev) ||
        (prev is _GroupHeader && prev.group == group);
    // 落到别的分组头之前 = 跨组；只有"列表最顶部且是本组头"才放行。
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

  Widget _tile(BuildContext context, Map<String, TaskList> byId, Task task) {
    final list = byId[task.listId];
    return TaskTile(
      task: task,
      listName: list?.name ?? '生活',
      listColorValue:
          listColor(task.listId, list?.color, context.colors.primary),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Container(
        width: double.infinity,
        color: context.appBackground,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );

  Widget _emptyState(BuildContext context, bool searching) {
    final text = searching
        ? '没找到匹配的任务'
        : switch (view) {
            ViewKind.today => '今天没有安排 🎉',
            ViewKind.undated => '都安排好了 👌',
            _ => '这里还没有内容',
          };
    return Center(
      child: Text(
        text,
        style: TextStyle(fontSize: 16, color: context.colors.onSurfaceVariant),
      ),
    );
  }

  String _bucketOf(Task t, DayBounds b) {
    final dueAt = t.dueAt;
    if (dueAt == null) return '待定';
    if (dueAt < b.todayStartMs) return '逾期';
    if (dueAt < b.tomorrowStartMs) return '今天';
    if (dueAt < b.dayAfterTomorrowStartMs) return '明天';
    if (dueAt >= b.weekStartMs && dueAt < b.nextWeekStartMs) return '本周';
    if (dueAt < b.nextMonthStartMs) return '本月';
    return '以后';
  }
}

Widget _chip(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
  Color? color,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
    child: ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}
