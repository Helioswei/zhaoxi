import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../domain/day_boundary.dart';
import '../../domain/view_kind.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../quick_voice/quick_voice_button.dart';
import '../task_edit/task_edit_sheet.dart';
import 'task_tile.dart';

class TaskListPage extends ConsumerWidget {
  const TaskListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(selectedViewProvider);
    final tasksAsync = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('朝夕'),
        actions: [
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
          if (view == ViewKind.today) const _UndatedBanner(),
          const Divider(height: 1),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => _TaskListBody(tasks: tasks, view: view),
              loading: () => const Center(child: CircularProgressIndicator()),
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
            tooltip: '新建任务',
            onPressed: () => openTaskEditSheet(context),
            child: const Icon(Icons.add),
          ),
        ],
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
            label: '全部',
            selected: selected == null,
            onTap: () => ref.read(selectedListIdProvider.notifier).select(null),
          ),
          for (final l in lists)
            _chip(
              label: l.name,
              selected: selected == l.id,
              color: listColor(l.id, l.color),
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
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final v in ViewKind.defaultOrder)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(v.label),
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
      onTap: () => ref.read(selectedViewProvider.notifier).select(ViewKind.undated),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '还有 $count 件没定时间',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TaskListBody extends ConsumerWidget {
  const _TaskListBody({required this.tasks, required this.view});

  final List<Task> tasks;
  final ViewKind view;

  static const _bucketOrder = ['逾期', '今天', '明天', '本周', '本月', '以后', '待定'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) return _emptyState();

    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final byId = {for (final l in lists) l.id: l};

    if (view != ViewKind.all) {
      return ListView.separated(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: tasks.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) => _tile(byId, tasks[i]),
      );
    }

    // 「全部」视图：按时间分组，每条只进第一个匹配的组。
    final bounds = DayBounds();
    final groups = <String, List<Task>>{for (final b in _bucketOrder) b: []};
    for (final t in tasks) {
      groups[_bucketOf(t, bounds)]!.add(t);
    }
    final children = <Widget>[];
    for (final b in _bucketOrder) {
      final items = groups[b]!;
      if (items.isEmpty) continue;
      children.add(_sectionHeader('$b（${items.length}）'));
      for (final t in items) {
        children.add(_tile(byId, t));
        children.add(const Divider(height: 1));
      }
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: children,
    );
  }

  Widget _tile(Map<String, TaskList> byId, Task task) {
    final list = byId[task.listId];
    return TaskTile(
      task: task,
      listName: list?.name ?? '生活',
      listColorValue: listColor(task.listId, list?.color),
    );
  }

  Widget _sectionHeader(String text) => Container(
        width: double.infinity,
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _emptyState() {
    final text = switch (view) {
      ViewKind.today => '今天没有安排 🎉',
      ViewKind.undated => '都安排好了 👌',
      _ => '这里还没有内容',
    };
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
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

Widget _chip({
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
