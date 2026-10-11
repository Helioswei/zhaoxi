import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../providers/app_providers.dart';
import '../../ui/due_label.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import '../task_edit/task_edit_sheet.dart';

class TaskTile extends ConsumerWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.listName,
    required this.listColorValue,
  });

  final Task task;
  final String listName;
  final Color listColorValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.status == 1;
    final label = dueLabel(task);
    final colors = context.colors;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        final repo = ref.read(taskRepositoryProvider);
        repo.softDelete(task.id);
        showUndoSnack(context, '已删除', () => repo.restore(task.id));
      },
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: () => openTaskEditSheet(context, task: task),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: done ? '标记为未完成' : '完成',
                  iconSize: 26,
                  onPressed: () async {
                    final repo = ref.read(taskRepositoryProvider);
                    await repo.setCompleted(task, !done);
                    if (!context.mounted) return;
                    showUndoSnack(
                      context,
                      done ? '已标记为未完成' : '已完成 ✓',
                      () => repo.setCompleted(task, done),
                    );
                  },
                  icon: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? colors.onSurfaceVariant : colors.primary,
                  ),
                ),
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
                          fontSize: 18,
                          color: done ? colors.onSurfaceVariant : colors.onSurface,
                          decoration: done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if ((task.note ?? '').isNotEmpty)
                        Text(
                          task.note!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.text,
                      style: TextStyle(
                        fontSize: 13,
                        color: dueLabelColor(colors, label),
                        fontWeight:
                            label.overdue ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: listColorValue,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          listName,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
