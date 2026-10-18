import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../providers/app_providers.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_pill.dart';

/// 回收站：删除的任务先来这里（软删除），可以恢复或彻底删除。
class RecycleBinPage extends ConsumerWidget {
  const RecycleBinPage({super.key});

  static const routeName = '/recycle';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(deletedTasksProvider).value ?? const <Task>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (tasks.isNotEmpty)
            IconButton(
              tooltip: '清空回收站',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => _clearAll(context, ref, tasks.length),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? const AppEmptyState(
              emoji: '🗑️',
              text: '回收站是空的',
              hint: '删掉的任务会先来这里，40 天后自动清理',
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '回收站保留 40 天，过期自动清理；超期前可随时恢复。',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => _row(context, ref, tasks[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Task task) {
    final t = context.tokens;
    final when = DateFormat('M月d日 HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(task.updatedAt));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: t.textSecondary,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '删除于 $when',
                      style: TextStyle(fontSize: 12, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => ref.read(taskRepositoryProvider).restore(task.id),
                child: const Text('恢复'),
              ),
              IconButton(
                tooltip: '彻底删除',
                icon: Icon(Icons.delete_outline, color: t.danger),
                onPressed: () => _hardDelete(context, ref, task),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _hardDelete(
      BuildContext context, WidgetRef ref, Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('彻底删除？'),
        content: Text('「${task.title}」将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(taskRepositoryProvider).hardDelete(task.id);
  }

  Future<void> _clearAll(
      BuildContext context, WidgetRef ref, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空回收站？'),
        content: Text('$count 条任务将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(taskRepositoryProvider).hardDeleteAll();
    if (context.mounted) showInfoSnack(context, '回收站已清空');
  }
}
