import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../domain/export_options.dart';
import '../../providers/app_providers.dart';
import '../../services/export_service.dart';
import '../../services/file_delivery.dart';
import '../../services/import_service.dart';
import '../../services/notification_service.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  static const routeName = '/export';

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportOptions _options = const ExportOptions();
  ExportBundle? _preview;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    if (_options.format == ExportFormat.json) {
      setState(() => _preview = null);
      return;
    }
    final bundle =
        await ref.read(exportServiceProvider).collectRange(_options);
    if (!mounted) return;
    setState(() => _preview = bundle);
  }

  void _update(ExportOptions next) {
    setState(() => _options = next);
    _refreshPreview();
  }

  Future<void> _applyMonthlyReport() async {
    final lists = ref.read(listsProvider).value ?? const <TaskList>[];
    String? workId;
    for (final l in lists) {
      if (l.id == 'list-work') workId = l.id;
    }
    _update(ExportOptions.monthlyReport(workListId: workId));
  }

  String _fileStamp() {
    final range = _options.resolveRange();
    final fmt = DateFormat('yyyyMMdd');
    final listLabel = _options.listId == null
        ? 'all'
        : (ref.read(listsProvider).value
                    ?.firstWhere((l) => l.id == _options.listId,
                        orElse: () => TaskList(
                              id: 'x',
                              name: 'list',
                              color: null,
                              sortOrder: 0,
                              isBuiltin: false,
                              deleted: false,
                              updatedAt: 0,
                              originDevice: 'x',
                            ))
                    .name ??
                'list');
    return 'zhaoxi-${fmt.format(range.from)}-${fmt.format(range.to.subtract(const Duration(days: 1)))}-$listLabel';
  }

  Future<void> _export({required bool saveAs}) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(exportServiceProvider);
      if (_options.format == ExportFormat.json) {
        final json = await svc.buildBackupJson();
        final bytes = Uint8List.fromList(utf8.encode(json));
        await _deliver(
          'zhaoxi-backup-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json',
          bytes,
          'application/json',
          saveAs,
        );
      } else {
        final bundle = await svc.collectRange(_options);
        if (bundle.isEmpty) {
          if (mounted) showInfoSnack(context, '这个时间段没有符合条件的记录');
          return;
        }
        if (_options.format == ExportFormat.markdown) {
          final md = svc.toMarkdown(bundle);
          await _deliver(
            '${_fileStamp()}.md',
            Uint8List.fromList(utf8.encode(md)),
            'text/markdown',
            saveAs,
          );
        } else {
          final pdf = await svc.toPdf(bundle);
          await _deliver('${_fileStamp()}.pdf', pdf, 'application/pdf', saveAs);
        }
      }
      if (mounted) showInfoSnack(context, '已导出');
    } catch (e) {
      if (mounted) showInfoSnack(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deliver(
    String fileName,
    Uint8List bytes,
    String mime,
    bool saveAs,
  ) async {
    if (saveAs) {
      await saveBytesAs(fileName: fileName, bytes: bytes, mimeType: mime);
    } else {
      await shareBytes(fileName: fileName, bytes: bytes);
    }
  }

  Future<void> _import({required bool overwrite}) async {
    if (overwrite) {
      final ok = await _confirmOverwrite();
      if (ok != true) return;
    }
    final content = await pickTextFile();
    if (content == null) return;
    if (!mounted) return;

    setState(() => _busy = true);
    try {
      // 覆盖导入前先取消全部通知，避免幽灵通知。
      if (overwrite) {
        await NotificationService.instance.cancelAll();
      }
      final result = await ref
          .read(importServiceProvider)
          .importJson(content, overwrite: overwrite);
      if (overwrite) {
        await ref.read(taskRepositoryProvider).rescheduleAll();
      }
      await _refreshPreview();
      if (mounted) showInfoSnack(context, result.summary);
    } on ImportException catch (e) {
      if (mounted) showInfoSnack(context, e.message);
    } catch (e) {
      if (mounted) showInfoSnack(context, '导入失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('覆盖导入？'),
        content: const Text('会清空当前所有任务与清单，且无法撤销。建议先导出一份 JSON 备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.colors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('覆盖'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _options;
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final isJson = o.format == ExportFormat.json;

    return Scaffold(
      appBar: AppBar(title: const Text('导出 / 备份')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _busy ? null : _applyMonthlyReport,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('一键「月报」：本月 + 工作 + 仅已完成 + 按周'),
              ),
            ),
          ),
          _section('范围'),
          _chips(
            values: ExportRangePreset.values,
            selected: o.preset,
            label: (v) => v.label,
            onSelect: (v) => _update(o.copyWith(preset: v)),
          ),
          if (o.preset == ExportRangePreset.custom) _customRangeRow(),
          _section('清单'),
          _chips<String?>(
            values: [null, ...lists.map((l) => l.id)],
            selected: o.listId,
            label: (v) => v == null
                ? '全部'
                : lists.firstWhere((l) => l.id == v).name,
            onSelect: (v) => _update(o.copyWith(listId: v)),
          ),
          _section('内容'),
          _chips(
            values: ExportContent.values,
            selected: o.content,
            label: (v) => v.label,
            onSelect: (v) => _update(o.copyWith(content: v)),
          ),
          _section('分组'),
          if (isJson)
            const _DisabledHint('JSON 为完整备份，忽略范围 / 清单 / 分组')
          else
            _chips(
              values: ExportGrouping.values,
              selected: o.grouping,
              label: (v) => v.label,
              onSelect: (v) => _update(o.copyWith(grouping: v)),
            ),
          _section('格式'),
          _chips(
            values: ExportFormat.values,
            selected: o.format,
            label: (v) => v.label,
            onSelect: (v) => _update(o.copyWith(format: v)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              _previewText(isJson),
              style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _export(saveAs: false),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('分享 / 发送'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _export(saveAs: true),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('另存为'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          _section('导入备份（JSON）'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '合并：只补本地没有或更旧的记录，安全。\n覆盖：清空后写入，需二次确认。',
              style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _import(overwrite: false),
                    child: const Text('合并导入'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.error,
                    ),
                    onPressed: _busy ? null : () => _import(overwrite: true),
                    child: const Text('覆盖导入'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _previewText(bool isJson) {
    if (isJson) return '将导出全部数据（含已删除标记），用于备份 / 换设备恢复。';
    final p = _preview;
    if (p == null) return '正在统计…';
    if (p.isEmpty) return '这个时间段没有符合条件的记录。';
    return '将导出：${p.summary}。';
  }

  Widget _customRangeRow() {
    final range = _options.resolveRange();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickCustom(from: true),
              child: Text(DateFormat('yyyy-MM-dd').format(range.from)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('~'),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickCustom(from: false),
              child: Text(
                DateFormat('yyyy-MM-dd')
                    .format(range.to.subtract(const Duration(days: 1))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustom({required bool from}) async {
    final range = _options.resolveRange();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? range.from : range.to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _update(
      from
          ? _options.copyWith(customFrom: picked)
          : _options.copyWith(customTo: picked),
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

  Widget _chips<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onSelect,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              onSelected: (_) => onSelect(v),
            ),
        ],
      ),
    );
  }
}

class _DisabledHint extends StatelessWidget {
  const _DisabledHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 13, color: context.colors.onSurfaceVariant),
        ),
      ),
    );
  }
}
