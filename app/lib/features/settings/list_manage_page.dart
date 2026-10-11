import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/dao/list_dao.dart';
import '../../data/db/database.dart';
import '../../data/repo/list_repository.dart';
import '../../providers/app_providers.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

/// 清单管理（03 §3.5）：
/// - 内置「工作 / 生活」**可改名、改色，但不可删除**；
/// - 自定义清单可新增 / 改名 / 改色 / 删除，删除前需选任务归属。
class ListManagePage extends ConsumerWidget {
  const ListManagePage({super.key});

  static const routeName = '/lists';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];

    return Scaffold(
      appBar: AppBar(title: const Text('清单管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '「工作」「生活」是内置清单：可以改名、改色，但不能删除。',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: lists.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final list = lists[i];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 10,
                    backgroundColor:
                        listColor(list.id, list.color, context.colors.primary),
                  ),
                  title: Text(list.name),
                  subtitle: list.isBuiltin ? const Text('内置') : null,
                  onTap: () => _rename(context, ref, list),
                  trailing: PopupMenuButton<String>(
                    tooltip: '更多',
                    onSelected: (value) => switch (value) {
                      'rename' => _rename(context, ref, list),
                      'color' => _pickColor(context, ref, list),
                      'delete' => _delete(context, ref, list, lists),
                      _ => null,
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'rename', child: Text('改名')),
                      const PopupMenuItem(value: 'color', child: Text('改颜色')),
                      if (!list.isBuiltin)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除',
                              style: TextStyle(color: context.colors.error)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新增清单'),
      ),
    );
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, TaskList list) async {
    final controller = TextEditingController(text: list.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清单名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(listRepositoryProvider).rename(list.id, result);
  }

  Future<void> _pickColor(
      BuildContext context, WidgetRef ref, TaskList list) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final hex in ListRepository.palette)
              InkWell(
                onTap: () => Navigator.pop(ctx, hex),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      listColor(list.id, hex, Theme.of(ctx).colorScheme.primary),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (chosen == null) return;
    await ref.read(listRepositoryProvider).setColor(list.id, chosen);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增清单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 12,
          decoration: const InputDecoration(
            hintText: '例如：买菜',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(listRepositoryProvider).addCustom(name: name);
    if (context.mounted) showInfoSnack(context, '已创建清单「${name.trim()}」');
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskList list,
    List<TaskList> all,
  ) async {
    final repo = ref.read(listRepositoryProvider);
    final count = await repo.countTasks(list.id);
    if (!context.mounted) return;
    final others = all.where((l) => l.id != list.id).toList();
    if (others.isEmpty) return;

    var targetId = others.any((l) => l.id == kFallbackListId)
        ? kFallbackListId
        : others.first.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('删除「${list.name}」？'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(count == 0
                  ? '这个清单下没有任务。'
                  : '这个清单下有 $count 条任务，删除后会移到：'),
              if (count > 0) ...[
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: targetId,
                  isExpanded: true,
                  items: [
                    for (final l in others)
                      DropdownMenuItem(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) =>
                      setState(() => targetId = v ?? targetId),
                ),
              ],
            ],
          ),
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
      ),
    );
    if (confirmed != true) return;
    await repo.deleteWithReassign(list.id, toListId: targetId);
    if (context.mounted) showInfoSnack(context, '已删除清单「${list.name}」');
  }
}
