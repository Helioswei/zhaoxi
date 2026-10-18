import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../domain/export_options.dart';
import '../../providers/app_providers.dart';
import '../../services/export_service.dart';
import '../../services/file_delivery.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/widgets/app_pill.dart';

/// 导出页（与「备份与恢复」「回收站」同为页面，行为一致）。
///
/// 默认只露 3 组选择（范围 / 清单 / 格式），低频项收进「更多选项」；
/// 分组不再让用户选，按范围自动决定（≤14 天按日，否则按周）。
class ExportPage extends ConsumerStatefulWidget {
  const ExportPage({super.key});

  static const routeName = '/export';

  @override
  ConsumerState<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends ConsumerState<ExportPage> {
  ExportRangePreset _preset = ExportRangePreset.thisMonth;
  ExportFormat _format = ExportFormat.pdf;
  ExportContent _content = ExportContent.doneAndOpen;
  bool _includeDeleted = false;
  String? _listId;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final lists = ref.read(listsProvider).value ?? const <TaskList>[];
    for (final l in lists) {
      if (l.id == 'list-work') _listId = l.id;
    }
  }

  ExportGrouping get _grouping {
    final probe = ExportOptions(
      preset: _preset,
      customFrom: _customFrom,
      customTo: _customTo,
    );
    final range = probe.resolveRange();
    final days = range.to.difference(range.from).inDays;
    return days <= 14 ? ExportGrouping.day : ExportGrouping.week;
  }

  ExportOptions get _options => ExportOptions(
        preset: _preset,
        format: _format,
        grouping: _grouping,
        content: _content,
        includeDeleted: _includeDeleted,
        listId: _listId,
        customFrom: _customFrom,
        customTo: _customTo,
      );

  bool get _isText => _format == ExportFormat.text;

  Future<void> _run({required bool toFile}) async {
    setState(() => _busy = true);
    try {
      final svc = ref.read(exportServiceProvider);
      final options = _options;
      final bundle = await svc.collectRange(options);
      if (bundle.isEmpty) {
        if (mounted) showInfoSnack(context, '这个时间段没有符合条件的记录');
        return;
      }

      if (options.format == ExportFormat.text) {
        final md = svc.toMarkdown(bundle);
        await Clipboard.setData(ClipboardData(text: md));
        if (mounted) {
          showInfoSnack(context, '已复制到剪贴板，可以直接粘贴到报告里');
        }
        return;
      }

      final (bytes, ext, mime) = await _render(svc, bundle, options);
      final name = '${_stamp(options)}.$ext';
      if (toFile) {
        await saveBytesAs(fileName: name, bytes: bytes, mimeType: mime);
        if (mounted) showInfoSnack(context, '已保存');
      } else {
        await shareBytes(fileName: name, bytes: bytes);
      }
    } catch (e) {
      if (mounted) showInfoSnack(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(Uint8List, String, String)> _render(
    ExportService svc,
    ExportBundle bundle,
    ExportOptions options,
  ) async {
    switch (options.format) {
      case ExportFormat.pdf:
        return (await svc.toPdf(bundle), 'pdf', 'application/pdf');
      case ExportFormat.word:
        return (
          await svc.toDocx(bundle),
          'docx',
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        );
      case ExportFormat.xlsx:
        return (
          await svc.toXlsx(bundle),
          'xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        );
      case ExportFormat.markdown:
        return (
          Uint8List.fromList(utf8.encode(svc.toMarkdown(bundle))),
          'md',
          'text/markdown'
        );
      case ExportFormat.text:
        return (Uint8List(0), 'txt', 'text/plain');
    }
  }

  String _stamp(ExportOptions o) {
    final range = o.resolveRange();
    final fmt = DateFormat('yyyyMMdd');
    final list = ref
            .read(listsProvider)
            .value
            ?.where((l) => l.id == o.listId)
            .map((l) => l.name)
            .firstOrNull ??
        '全部';
    return '朝夕-记录-${fmt.format(range.from)}-${fmt.format(range.to.subtract(const Duration(days: 1)))}-$list';
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];

    return Scaffold(
      appBar: AppBar(title: const Text('导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _label('哪一段时间'),
          _pills<ExportRangePreset>(
            values: ExportRangePreset.values,
            selected: _preset,
            label: (v) => v.label,
            onSelect: (v) => setState(() => _preset = v),
          ),
          if (_preset == ExportRangePreset.custom) _customRange(),

          _label('哪些清单'),
          _pills<String?>(
            values: [null, ...lists.map((l) => l.id)],
            selected: _listId,
            label: (v) =>
                v == null ? '全部' : lists.firstWhere((l) => l.id == v).name,
            onSelect: (v) => setState(() => _listId = v),
          ),

          _label('格式'),
          _formatRow(),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'MD = Markdown 文件 · 复制 = 拷到剪贴板',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),

          _label('内容'),
          _pills<ExportContent>(
            values: ExportContent.values,
            selected: _content,
            label: (v) => v.label,
            onSelect: (v) => setState(() => _content = v),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeDeleted,
            onChanged: (v) => setState(() => _includeDeleted = v ?? false),
            title: const Text('包含已删除（回收站）'),
            subtitle: const Text('在末尾加一节「已删除」'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _run(toFile: false),
                  icon: Icon(_isText ? Icons.copy : Icons.ios_share),
                  label: Text(
                    _isText ? '复制文字' : '分享 / 发送',
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
              ),
              if (!_isText)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _busy ? null : () => _run(toFile: true),
                    child: const Text('存到文件夹…'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customRange() {
    final range = _options.resolveRange();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickDate(from: true),
              child: Text(DateFormat('yyyy-MM-dd').format(range.from)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('~'),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickDate(from: false),
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

  Future<void> _pickDate({required bool from}) async {
    final range = _options.resolveRange();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? range.from : range.to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _customFrom = picked;
      } else {
        _customTo = picked;
      }
    });
  }

  /// 格式：5 个等宽分段，一行放得下。
  Widget _formatRow() {
    const values = [
      ExportFormat.pdf,
      ExportFormat.word,
      ExportFormat.xlsx,
      ExportFormat.markdown,
      ExportFormat.text,
    ];
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: _formatSegment(values[i])),
        ],
      ],
    );
  }

  Widget _formatSegment(ExportFormat v) {
    final t = context.tokens;
    final selected = _format == v;
    return Material(
      color: selected ? t.chipSelectedBg : Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => setState(() => _format = v),
        child: SizedBox(
          height: 38,
          child: Center(
            child: Text(
              switch (v) {
                ExportFormat.pdf => 'PDF',
                ExportFormat.word => 'Word',
                ExportFormat.xlsx => 'Excel',
                ExportFormat.markdown => 'MD',
                ExportFormat.text => '复制',
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: selected ? t.primary : t.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );

  Widget _pills<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final v in values)
          AppPill(
            label: label(v),
            selected: v == selected,
            onTap: () => onSelect(v),
          ),
      ],
    );
  }
}
