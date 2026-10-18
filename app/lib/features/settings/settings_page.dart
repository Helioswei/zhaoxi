import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import '../export/monthly_report_sheet.dart';
import '../../services/notification_service.dart';
import '../../ui/theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  static const routeName = '/settings';

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool? _notifEnabled;
  bool? _exact;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final svc = NotificationService.instance;
    final enabled = await svc.notificationsEnabled();
    final exact = await svc.canScheduleExact();
    if (!mounted) return;
    setState(() {
      _notifEnabled = enabled;
      _exact = exact;
    });
  }

  Future<void> _requestPermissions() async {
    await NotificationService.instance.requestPermissions();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final offset = ref.watch(remindOffsetProvider);
    final mode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final style = ref.watch(styleProvider);
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section(context, '外观'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final m in const [
                  ThemeMode.system,
                  ThemeMode.light,
                  ThemeMode.dark,
                ])
                  ChoiceChip(
                    label: Text(switch (m) {
                      ThemeMode.system => '跟随系统',
                      ThemeMode.light => '浅色',
                      ThemeMode.dark => '深色',
                    }),
                    selected: mode == m,
                    onSelected: (_) =>
                        ref.read(themeModeProvider.notifier).select(m),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in AppStyleId.values)
                  ChoiceChip(
                    label: Text(s.label),
                    selected: style == s,
                    onSelected: (_) =>
                        ref.read(styleProvider.notifier).select(s),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '风格：${style.description}（可随时切换对比）',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                for (final s in const ['normal', 'large'])
                  ChoiceChip(
                    label: Text(s == 'large' ? '大字号' : '标准字号'),
                    selected: fontScale == s,
                    onSelected: (_) =>
                        ref.read(fontScaleProvider.notifier).select(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.view_list_outlined),
            title: const Text('视图管理'),
            subtitle: const Text('首页时间视图的显示 / 顺序 / 名称'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/views'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('清单管理'),
            subtitle: const Text('工作 / 生活等清单的名称、颜色、增删'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/lists'),
          ),
          const Divider(),
          _section(context, '提醒'),
          _statusTile(
            context,
            title: '通知权限',
            ok: _notifEnabled,
            okText: '已开启',
            badText: '未开启 —— 到点不会提醒',
          ),
          _statusTile(
            context,
            title: '精确提醒',
            ok: _exact,
            okText: '已开启',
            badText: '未开启 —— 提醒可能延迟几分钟',
          ),
          if (_exact == false || _notifEnabled == false)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FilledButton.tonal(
                onPressed: _requestPermissions,
                child: const Text('去开启'),
              ),
            ),
          ListTile(
            title: const Text('默认提前量'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final m in const [0, 5, 15, 30])
                    ChoiceChip(
                      label: Text(m == 0 ? '准时' : '提前 $m 分'),
                      selected: offset == m,
                      onSelected: (_) =>
                          ref.read(remindOffsetProvider.notifier).select(m),
                    ),
                ],
              ),
            ),
          ),
          const Divider(),
          _section(context, '数据'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('导出'),
            subtitle: const Text('PDF / Word / Excel / Markdown / 文字'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openMonthlyReportSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('备份与恢复'),
            subtitle: const Text('全量 JSON 备份 / 从备份恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/export'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('回收站'),
            subtitle: const Text('删过的任务先来这里，可恢复或彻底删除'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/recycle'),
          ),
          const Divider(),
          _section(context, '关于'),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('0.1.0 · MVP（M0–M3）'),
          ),
          const ListTile(
            title: Text('数据'),
            subtitle: Text('任务数据只在这台设备上，不会上传'),
          ),
          const ListTile(
            title: Text('开源许可'),
            subtitle: Text('MIT（代码） / SIL OFL-1.1（思源宋体子集）'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '朝夕',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );

  Widget _statusTile(
    BuildContext context, {
    required String title,
    required bool? ok,
    required String okText,
    required String badText,
  }) {
    final isOk = ok ?? true;
    return ListTile(
      title: Text(title),
      subtitle: Text(isOk ? okText : badText),
      trailing: Icon(
        isOk ? Icons.check_circle : Icons.error_outline,
        color: isOk ? context.colors.primary : context.colors.error,
      ),
    );
  }
}
