import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/dao/settings_dao.dart';
import '../../providers/app_providers.dart';
import '../../services/file_delivery.dart';
import '../../services/tree_source.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import 'restore_flow.dart';

/// 「从文件恢复」的自研文件列表（方案 C）。
///
/// 只借系统界面做一次性目录授权，之后列表自己在 App 里画：
/// 名字、大小、时间、搜索都归我们管，不受系统选择器渲染问题影响。
class RestoreFilesPage extends ConsumerStatefulWidget {
  const RestoreFilesPage({super.key, this.pickOnly = false});

  static const routeName = '/restore-files';

  /// 只为拿一个目录授权（备份页「存到文件夹」用）：选完立刻带着结果返回。
  final bool pickOnly;

  @override
  ConsumerState<RestoreFilesPage> createState() => _RestoreFilesPageState();
}

class _RestoreFilesPageState extends ConsumerState<RestoreFilesPage> {
  final _searchCtrl = TextEditingController();

  String? _treeUri;
  String _folderName = '';
  List<BackupFileEntry> _entries = const [];

  /// 首次加载 / 换文件夹：此时还没有内容可显示，才铺满屏转圈。
  bool _loading = false;

  /// 有请求在飞：按钮置灰，但已有列表原地保留（下拉刷新不该让内容消失）。
  bool _refreshing = false;

  /// 防连点：双击文件会叠出两个「怎么恢复？」。
  bool _opening = false;

  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadSavedFolder();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  SettingsDao get _dao => ref.read(databaseProvider).settingsDao;

  Future<void> _loadSavedFolder() async {
    final uri = await _dao.get(SettingsKeys.restoreTreeUri);
    if (!mounted) return;
    if (uri == null || uri.isEmpty) return;
    final name = await _dao.get(SettingsKeys.restoreTreeName);
    if (!mounted) return;
    setState(() {
      _treeUri = uri;
      _folderName = name ?? '已选文件夹';
    });
    await _refresh();
  }

  Future<void> _pickFolder() async {
    if (_refreshing) return;
    AuthorizedFolder? folder;
    try {
      folder = await TreeSource.pickFolder();
    } on PlatformException catch (e) {
      // 系统原文是英文技术话，只留在日志里。
      debugPrint('open tree failed: ${e.message}');
      if (mounted) showInfoSnack(context, '打不开系统的文件夹界面，再试一次');
      return;
    } on MissingPluginException {
      if (mounted) showInfoSnack(context, '这个设备上用不了，试试下面的系统文件选择器');
      return;
    }
    final picked = folder;
    if (picked == null || !mounted) return;

    // 换了文件夹就把旧授权放掉，不占系统授予名额。
    final old = _treeUri;
    if (old != null && old != picked.uri) {
      await TreeSource.release(old);
    }
    await _dao.set(SettingsKeys.restoreTreeUri, picked.uri);
    await _dao.set(SettingsKeys.restoreTreeName, picked.name);
    if (!mounted) return;
    if (widget.pickOnly) {
      // 只为拿授权：拿到就回去，让调用方接着干活。
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _treeUri = picked.uri;
      _folderName = picked.name;
      _entries = const [];
      _error = null;
      _query = '';
      _searchCtrl.clear();
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    final uri = _treeUri;
    if (uri == null) return;
    setState(() {
      _refreshing = true;
      // 已经有内容就原地刷新；只有手里什么都没有时才转圈。
      _loading = _entries.isEmpty;
      _error = null;
    });
    try {
      final list = await TreeSource.list(uri);
      if (!mounted) return;
      setState(() => _entries = list);
    } on PlatformException catch (e) {
      debugPrint('list backup files failed: ${e.message}');
      if (!mounted) return;
      setState(() => _error = '读不到这个文件夹，授权可能已经失效了');
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _error = '这个功能在这个设备上用不了');
    } catch (e) {
      debugPrint('list backup files failed: $e');
      if (!mounted) return;
      setState(() => _error = '读不到这个文件夹');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _open(BackupFileEntry entry) async {
    if (_opening) return;
    _opening = true;
    try {
      final content = await TreeSource.readText(entry.uri);
      if (!mounted) return;
      if (content == null || content.trim().isEmpty) {
        showInfoSnack(context, '读不到这个文件，换一个试试');
        return;
      }
      await showRestoreFlow(context, ref, content, fileName: entry.name);
    } finally {
      _opening = false;
    }
  }

  /// 兜底：系统文件选择器（在部分机型上体验差，但万一目录授权也走不通）。
  Future<void> _openViaSystemPicker() async {
    final content = await pickTextFile();
    if (content == null || !mounted) return;
    await showRestoreFlow(context, ref, content);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('从文件恢复'),
        actions: [
          // 「换文件夹」放在列表头部（贴着文件夹名），这里不再重复一份。
          if (_treeUri != null)
            IconButton(
              tooltip: '刷新',
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _treeUri == null ? _buildGuide() : _buildList(),
    );
  }

  /// 还没授权过：说清楚要做什么（系统那一步只需点一下，不用认文件名）。
  Widget _buildGuide() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: [
        Icon(
          Icons.folder_copy_outlined,
          size: 56,
          color: context.colors.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          '选一个放备份的文件夹',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Text(
          '选好之后，这里只列这个文件夹里的备份（.json / .txt，含子文件夹），'
          '文件名、大小、时间都会清楚列出来。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '下一步是系统界面，里面的文件名可能是空白 —— 不用管，直接点「使用此文件夹」就行。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '如果系统说「无法使用此文件夹」：说明选到了手机根目录或「下载 / Download」根目录，'
          '系统不让给 —— 往下多选一层就行。没有合适的文件夹，用手机自带的「文件管理」'
          '先建一个，再回来选。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _pickFolder,
            icon: const Icon(Icons.folder_open),
            label: const Text('选择文件夹'),
          ),
        ),
        // 只挑目录时不需要"用系统选择器读文件"这条兜底。
        if (!widget.pickOnly) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _openViaSystemPicker,
            child: const Text('或者用系统文件选择器试一次'),
          ),
        ],
      ],
    );
  }

  Widget _buildList() {
    final shown = _query.isEmpty
        ? _entries
        : _entries
              .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.folder, size: 18, color: context.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _folderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _refreshing ? null : _pickFolder,
                  child: const Text('换文件夹'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '只看这个文件夹里的 .json / .txt 备份，新的排前面。',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          if (_entries.length > 5)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: '搜索文件名',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _emptyState(
              icon: Icons.folder_off_outlined,
              title: _error!,
              message: '也可能是这个文件夹被删了或移走了。重新选一次就好。',
              actions: [
                TextButton(
                  onPressed: _refreshing ? null : _pickFolder,
                  child: const Text('重新选一个文件夹'),
                ),
              ],
            )
          else if (shown.isEmpty)
            _emptyState(
              icon: Icons.inbox_outlined,
              title: _query.isEmpty ? '这个文件夹里没有备份文件' : '没有匹配的文件',
              message: _query.isEmpty
                  ? '备份页的「存到文件夹」会直接存到这里。文件在别处的话，'
                        '可以在微信 / QQ 里长按它 → 分享到朝夕，不用经过文件夹。'
                  : null,
              actions: [
                // 搜不到该清搜索，而不是让人去换文件夹。
                if (_query.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: const Text('清除搜索'),
                  ),
                if (_query.isEmpty)
                  TextButton(
                    onPressed: _refreshing ? null : _refresh,
                    child: const Text('刷新'),
                  ),
                if (_query.isEmpty)
                  TextButton(
                    onPressed: _refreshing ? null : _pickFolder,
                    child: const Text('换一个文件夹'),
                  ),
              ],
            )
          else
            for (final e in shown) _fileTile(e),
        ],
      ),
    );
  }

  Widget _fileTile(BackupFileEntry e) {
    final when = e.modified > 0
        ? DateFormat('MM-dd HH:mm').format(
            DateTime.fromMillisecondsSinceEpoch(e.modified),
          )
        : null;
    final meta = [
      if (e.folder.isNotEmpty) e.folder,
      if (e.size >= 0) _size(e.size),
      ?when,
    ].join(' · ');

    return ListTile(
      leading: Icon(
        e.isJson ? Icons.description_outlined : Icons.article_outlined,
        color: context.colors.primary,
      ),
      title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(meta, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _open(e),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    String? message,
    List<Widget> actions = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 44, color: context.colors.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.onSurfaceVariant),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
