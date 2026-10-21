import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../domain/repeat_rule.dart';
import '../../providers/app_providers.dart';
import '../../ui/due_label.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_pill.dart';
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
    final t = context.tokens;
    final done = task.status == 1;
    final label = dueLabel(task);
    final repeat = RepeatRule.decode(task.repeatRule);
    final labelColor = dueLabelColor(context.tokens, label);

    Future<void> toggle() async {
      final repo = ref.read(taskRepositoryProvider);
      await repo.setCompleted(task, !done);
      if (!context.mounted) return;
      if (repeat != null && !done) {
        showUndoSnack(
          context,
          '已完成，已排到下一次 ↻',
          () => repo.restoreRepeatCompletion(task),
        );
      } else {
        showUndoSnack(
          context,
          done ? '已标记为未完成' : '已完成 ✓',
          () => repo.setCompleted(task, done),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Dismissible(
        key: ValueKey('task-${task.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: t.danger,
            borderRadius: BorderRadius.circular(t.cardRadius),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        onDismissed: (_) {
          final repo = ref.read(taskRepositoryProvider);
          repo.softDelete(task.id);
          showUndoSnack(context, '已删除', () => repo.restore(task.id));
        },
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(t.cardRadius),
            onTap: () => openTaskEditSheet(context, task: task),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: done ? '标记为未完成' : '完成',
                    iconSize: 28,
                    onPressed: toggle,
                    icon: Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? t.textSecondary : t.primary,
                    ),
                  ),
                  const SizedBox(width: 2),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: done ? t.textSecondary : t.textPrimary,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: t.textSecondary,
                          ),
                        ),
                        if ((task.note ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              task.note!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 已完成：只留时间徽章。左边的完成圆钮就是恢复入口，不再重复一个「恢复」按钮。
                  if (done)
                    AppBadge(label.text, color: labelColor)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppBadge(label.text, color: labelColor),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (repeat != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  '↻ ${repeat.freq.label}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: t.textSecondary,
                                  ),
                                ),
                              ),
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: listColorValue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              listName,
                              style: TextStyle(
                                fontSize: 11,
                                color: t.textSecondary,
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
      ),
    );
  }
}
