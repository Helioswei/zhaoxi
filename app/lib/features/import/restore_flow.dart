import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../../services/import_service.dart';
import '../../services/notification_service.dart';
import '../../ui/snack.dart';

/// 统一的「怎么恢复」流程：合并 / 覆盖 → 导入 → 人话提示。
///
/// 两个入口共用：
/// - 备份页的「恢复」按钮（本机自动备份 / 从文件恢复）
/// - 「分享到朝夕」：微信里点文件 → 分享 → 朝夕（不过系统文件选择器）
Future<void> showRestoreFlow(
  BuildContext context,
  WidgetRef ref,
  String content, {
  String? fileName,
}) async {
  final overwrite = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('怎么恢复？'),
      content: Text(
        fileName == null
            ? '合并：只补本地没有或更旧的记录，安全。\n'
                  '覆盖：清空后写入，需要二次确认。'
            : '要恢复这个文件吗？\n'
                  '$fileName\n\n'
                  '合并：只补本地没有或更旧的记录，安全。\n'
                  '覆盖：清空后写入，需要二次确认。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('合并'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('覆盖'),
        ),
      ],
    ),
  );
  if (overwrite == null || !context.mounted) return;

  if (overwrite) {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认覆盖？'),
        content: const Text('会清空当前所有任务与清单，且无法撤销。建议先导出一份备份。'),
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
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
  }

  try {
    if (overwrite) await NotificationService.instance.cancelAll();
    final result = await ref
        .read(importServiceProvider)
        .importJson(content, overwrite: overwrite);
    if (overwrite) {
      await ref.read(taskRepositoryProvider).rescheduleAll();
    }
    if (!context.mounted) return;
    showInfoSnack(context, result.summary);
  } on ImportException catch (e) {
    if (context.mounted) showInfoSnack(context, e.message);
  } catch (e) {
    debugPrint('import failed: $e');
    if (context.mounted) showInfoSnack(context, '导入失败，再试一次');
  }
}
