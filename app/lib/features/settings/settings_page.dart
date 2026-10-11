import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section('提醒'),
          _statusTile(
            title: '通知权限',
            ok: _notifEnabled,
            okText: '已开启',
            badText: '未开启 —— 到点不会提醒',
          ),
          _statusTile(
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
          _section('数据'),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('导出 / 备份'),
            subtitle: const Text('导出月报（Markdown/PDF）或全量备份（JSON），也可导入恢复'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/export'),
          ),
          const Divider(),
          _section('关于'),
          const ListTile(
            title: Text('版本'),
            subtitle: Text('0.1.0 · M0/M1'),
          ),
          const ListTile(
            title: Text('数据'),
            subtitle: Text('任务数据只在这台设备上，不会上传'),
          ),
          const ListTile(
            title: Text('开源许可'),
            subtitle: Text('MIT（代码） / SIL OFL-1.1（思源宋体子集）'),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _statusTile({
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
        color: isOk ? AppColors.primary : AppColors.danger,
      ),
    );
  }
}
