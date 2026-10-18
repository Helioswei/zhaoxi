import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../services/file_delivery.dart';
import '../../services/import_service.dart';
import '../../services/notification_service.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

/// 备份与恢复（低频、偏技术，单独一页；日常用户只用「导出月报」）。
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  static const routeName = '/backup';

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  List<File> _backups = const [];

  @override
  void initState() {
    super.initState();
    _refreshBackups();
  }

  Future<void> _refreshBackups() async {
    try {
      final files = await ref.read(backupServiceProvider).listBackups();
      if (!mounted) return;
      setState(() => _backups = files);
    } catch (_) {
      // 列不出来就不显示
    }
  }

  String get _backupSummary {
    if (_backups.isEmpty) return '还没有备份';
    final when = DateFormat('yyyy-MM-dd HH:mm')
        .format(_backups.first.statSync().modified);
    return '共 ${_backups.length} 份，最近一次 $when';
  }

  String get _jsonName =>
      '朝夕-备份-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';

  Future<void> _exportJson({required bool toFile}) async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(exportServiceProvider).buildBackupJson();
      final bytes = utf8.encode(json);
      if (toFile) {
        await saveBytesAs(
          fileName: _jsonName,
          bytes: bytes,
          mimeType: 'application/json',
        );
        if (mounted) showInfoSnack(context, '已保存');
      } else {
        await shareBytes(fileName: _jsonName, bytes: bytes);
      }
    } catch (e) {
      if (mounted) showInfoSnack(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final content = await pickTextFile();
    if (content == null || !mounted) return;

    final overwrite = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('怎么恢复？'),
        content: const Text('合并：只补本地没有或更旧的记录，安全。\n覆盖：清空后写入，需要二次确认。'),
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
    if (overwrite == null || !mounted) return;

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
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      if (overwrite) await NotificationService.instance.cancelAll();
      final result = await ref
          .read(importServiceProvider)
          .importJson(content, overwrite: overwrite);
      if (overwrite) {
        await ref.read(taskRepositoryProvider).rescheduleAll();
      }
      if (mounted) showInfoSnack(context, result.summary);
    } on ImportException catch (e) {
      if (mounted) showInfoSnack(context, e.message);
    } catch (e) {
      if (mounted) showInfoSnack(context, '导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      await ref.read(backupServiceProvider).backupNow();
      await _refreshBackups();
      if (mounted) showInfoSnack(context, '已备份到本机');
    } catch (e) {
      if (mounted) showInfoSnack(context, '备份失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _section('备份全量数据'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _exportJson(toFile: false),
                icon: const Icon(Icons.ios_share),
                label: const Text('分享备份文件（JSON）'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : () => _exportJson(toFile: true),
                child: const Text('存到文件夹…'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              '包含全部任务（含已删除）与清单；不含设备标识。可用于换手机 / 恢复误删。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 36),
          _section('从备份恢复'),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('选择备份文件…'),
            subtitle: const Text('合并或覆盖导入'),
            onTap: _busy ? null : _restore,
          ),
          const Divider(height: 36),
          _section('自动备份'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('本机自动备份'),
            subtitle: Text(_backupSummary),
            trailing: TextButton(
              onPressed: _busy ? null : _backupNow,
              child: const Text('立即备份'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '每天首次打开自动备份一份，保留最近 ${BackupService.keep} 份；'
              '备份存在应用私有目录。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
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
}
