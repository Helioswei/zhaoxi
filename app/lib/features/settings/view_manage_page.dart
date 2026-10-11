import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/view_kind.dart';
import '../../providers/app_providers.dart';
import '../../ui/theme/app_theme.dart';

/// 视图管理（US-028）：显示 / 排序 / 重命名。
/// `全部`、`已完成` 锁定不可隐藏（安全网，见 02 §2.2.1）。
class ViewManagePage extends ConsumerWidget {
  const ViewManagePage({super.key});

  static const routeName = '/views';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(viewConfigProvider);
    final notifier = ref.read(viewConfigProvider.notifier);
    final order = config.order;

    return Scaffold(
      appBar: AppBar(title: const Text('视图管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: context.colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '拖动排序、勾选显示、点击重命名。「全部」「已完成」必须显示。',
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
            child: ReorderableListView.builder(
              buildDefaultDragHandles: true,
              itemCount: order.length,
              onReorderItem: notifier.reorder,
              itemBuilder: (context, index) {
                final view = order[index];
                final hidden = config.isHidden(view);
                return ListTile(
                  key: ValueKey(view.id),
                  leading: Icon(_iconFor(view), color: context.colors.onSurfaceVariant),
                  title: Text(config.labelOf(view)),
                  subtitle: view.isLocked
                      ? const Text('安全网，必须显示')
                      : (hidden ? const Text('已隐藏') : null),
                  trailing: view.isLocked
                      ? Icon(Icons.lock_outline, color: context.colors.onSurfaceVariant)
                      : Switch(
                          value: !hidden,
                          onChanged: (on) => notifier.setHidden(view, !on),
                        ),
                  onTap: () => _rename(context, ref, view, config.labelOf(view)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ViewKind view,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名视图'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 8,
          decoration: InputDecoration(
            hintText: view.label,
            counterText: '',
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('恢复默认'),
          ),
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
    await ref.read(viewConfigProvider.notifier).rename(view, result);
  }

  IconData _iconFor(ViewKind v) => switch (v) {
        ViewKind.undated => Icons.inbox_outlined,
        ViewKind.today => Icons.today_outlined,
        ViewKind.tomorrow => Icons.event_outlined,
        ViewKind.week => Icons.date_range_outlined,
        ViewKind.month => Icons.calendar_month_outlined,
        ViewKind.later => Icons.update_outlined,
        ViewKind.all => Icons.list_alt_outlined,
        ViewKind.done => Icons.check_circle_outline,
      };
}
