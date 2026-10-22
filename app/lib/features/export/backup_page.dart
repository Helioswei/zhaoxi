import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../data/dao/settings_dao.dart';
import '../../providers/app_providers.dart';
import '../../services/backup_service.dart';
import '../../services/file_delivery.dart';
import '../../services/tree_source.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import '../import/restore_files_page.dart';
import '../import/restore_flow.dart';

/// 备份与恢复（低频页面，与「导出」「回收站」同级）。
///
/// - 手动备份：分享 / 存到文件夹
/// - 从文件恢复：合并 / 覆盖
/// - 自动备份：列出最近几份，可直接分享或恢复（不必先导出再导入）
class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  static const routeName = '/backup';

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;
  bool _showAll = false;
  bool _loadFailed = false;
  List<File> _backups = const [];

  /// 已授权的备份文件夹：写（存到文件夹）和读（从文件恢复）用的是同一个。
  String? _treeUri;
  String _treeName = '';

  @override
  void initState() {
    super.initState();
    _refreshBackups();
    _loadFolder();
  }

  Future<void> _loadFolder() async {
    final dao = ref.read(databaseProvider).settingsDao;
    final uri = await dao.get(SettingsKeys.restoreTreeUri);
    final name = await dao.get(SettingsKeys.restoreTreeName);
    if (!mounted) return;
    setState(() {
      _treeUri = (uri == null || uri.isEmpty) ? null : uri;
      _treeName = name ?? '文件夹';
    });
  }

  Future<void> _refreshBackups() async {
    setState(() => _loadFailed = false);
    try {
      final files = await ref.read(backupServiceProvider).listBackups();
      if (!mounted) return;
      setState(() => _backups = files);
    } catch (e) {
      debugPrint('listBackups failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  String get _backupSummary {
    if (_loadFailed) return '列表读取失败';
    if (_backups.isEmpty) return '还没有备份';
    final when = DateFormat('yyyy-MM-dd HH:mm')
        .format(_backups.first.statSync().modified);
    return '共 ${_backups.length} 份，最近一次 $when';
  }

  String get _jsonName =>
      '朝夕-备份-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';

  String _size(File f) {
    final bytes = f.lengthSync();
    return bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  Future<void> _exportJson({required bool toFile}) async {
    // Android 上「存到文件夹」= 直接写进已授权的备份文件夹，不弹系统对话框。
    if (toFile && Platform.isAndroid) {
      await _saveToFolder();
      return;
    }
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
      debugPrint('export backup failed: $e');
      if (mounted) showInfoSnack(context, '导出失败，再试一次');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 存进已授权的备份文件夹（Android）。没有授权过就先选一次，选完接着存。
  Future<void> _saveToFolder() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_treeUri == null) {
        final picked = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const RestoreFilesPage(pickOnly: true),
          ),
        );
        if (!mounted) return;
        await _loadFolder();
        if (picked != true || _treeUri == null) return;
      }
      final json = await ref.read(exportServiceProvider).buildBackupJson();
      final saved = await TreeSource.createFile(
        treeUri: _treeUri!,
        name: _jsonName,
        content: json,
        mimeType: 'application/json',
      );
      if (saved == null || !mounted) return;
      showInfoSnack(context, '已保存到「$_treeName」');
    } on PlatformException catch (e) {
      debugPrint('save to folder failed: ${e.code} ${e.message}');
      if (!mounted) return;
      showInfoSnack(
        context,
        e.code == 'no_write'
            ? '这个文件夹不让写，换一个（选「下载」里的子文件夹）'
            : '保存失败，换一个文件夹再试',
      );
    } catch (e) {
      debugPrint('save to folder failed: $e');
      if (mounted) showInfoSnack(context, '保存失败，再试一次');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareBackup(File file) async {
    try {
      await shareBytes(
        fileName: p.basename(file.path),
        bytes: await file.readAsBytes(),
      );
    } catch (e) {
      debugPrint('share backup failed: $e');
      if (mounted) showInfoSnack(context, '分享失败，再试一次');
    }
  }

  Future<void> _restoreFrom(File file) async {
    final content = await file.readAsString();
    if (!mounted) return;
    await _restoreContent(content);
  }

  Future<void> _restore() async {
    // 自研文件列表只为绕开 Android 系统选择器不显示文件名的问题（见 docs/08 D-7）。
    // 其他平台的选择器本来就正常，直接用，省掉两步无意义的点击。
    if (!Platform.isAndroid) {
      final content = await pickTextFile();
      if (content == null || !mounted) return;
      await _restoreContent(content);
      return;
    }
    await Navigator.of(context).pushNamed(RestoreFilesPage.routeName);
    if (!mounted) return;
    // 用户可能在里面换了文件夹，回来后按钮文案要跟着变。
    await _loadFolder();
    await _refreshBackups();
  }

  Future<void> _restoreContent(String content) async {
    setState(() => _busy = true);
    try {
      await showRestoreFlow(context, ref, content);
      await _refreshBackups();
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
      debugPrint('backup failed: $e');
      if (mounted) showInfoSnack(context, '备份失败，再试一次');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _showAll ? _backups : _backups.take(3).toList();

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
                icon: _busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.ios_share),
                label: Text(_busy ? '正在处理…' : '分享备份文件（JSON）'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : () => _exportJson(toFile: true),
                child: Text(
                  _treeUri == null ? '存到文件夹…' : '存到「$_treeName」',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              _treeUri == null
                  ? '包含全部任务（含已删除）与清单；不含设备标识。可用于换手机 / 恢复误删。'
                  : '直接写进「$_treeName」，保存后可在「从文件恢复」里找到它。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 36),

          _section('从文件恢复'),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('选择备份文件…'),
            subtitle: const Text('挑一份备份，合并或覆盖都行'),
            onTap: _busy ? null : _restore,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '找不到文件？在微信 / QQ 里长按备份文件 → 用其他应用打开（或分享）→ 朝夕，'
              '会直接进恢复，不用经过系统文件选择器。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
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
              '每天首次打开自动备份一份；数据没变就不新增。'
              '保留最近 ${BackupService.keep} 份，存在应用私有目录。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          if (_loadFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 18, color: context.colors.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '备份列表读不出来，可能是存储受阻',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _refreshBackups,
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else if (_backups.isNotEmpty) ...[
            for (final f in shown) _backupRow(f),
            if (_backups.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = !_showAll),
                    child: Text(
                      _showAll ? '收起' : '查看全部（${_backups.length}）',
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _backupRow(File file) {
    final when = DateFormat('MM-dd HH:mm').format(file.statSync().modified);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.description_outlined, size: 20),
      title: Text(when),
      subtitle: Text(_size(file)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _busy ? null : () => _shareBackup(file),
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _restoreFrom(file),
            child: const Text('恢复'),
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
