import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../domain/export_options.dart';
import '../../providers/app_providers.dart';
import '../../services/file_delivery.dart';
import '../../ui/snack.dart';
import '../../ui/theme/app_theme.dart';

/// 打开「导出月报」弹层（方案 B 的主入口，只有 4 个控件 + 折叠的高级项）。
Future<void> openMonthlyReportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(context.tokens.sheetRadius),
      ),
    ),
    builder: (_) => const MonthlyReportSheet(),
  );
}

class MonthlyReportSheet extends ConsumerStatefulWidget {
  const MonthlyReportSheet({super.key});

  @override
  ConsumerState<MonthlyReportSheet> createState() => _MonthlyReportSheetState();
}

class _MonthlyReportSheetState extends ConsumerState<MonthlyReportSheet> {
  ExportRangePreset _preset = ExportRangePreset.thisMonth;
  ExportFormat _format = ExportFormat.pdf;
  ExportGrouping _grouping = ExportGrouping.week;
  ExportContent _content = ExportContent.doneAndOpen;
  bool _includeDeleted = false;
  String? _listId;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _moreOpen = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final lists = ref.read(listsProvider).value ?? const <TaskList>[];
    // 默认「工作」清单（月报通常只要工作）
    for (final l in lists) {
      if (l.id == 'list-work') _listId = l.id;
    }
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

      final stamp = _stamp(options);
      if (options.format == ExportFormat.markdown) {
        final md = svc.toMarkdown(bundle);
        final bytes = utf8.encode(md);
        if (toFile) {
          await saveBytesAs(
            fileName: '$stamp.md',
            bytes: bytes,
            mimeType: 'text/markdown',
          );
        } else {
          await Clipboard.setData(ClipboardData(text: md));
          if (mounted) {
            showInfoSnack(context, '已复制到剪贴板，可以直接粘贴到报告里');
          }
        }
      } else {
        final pdf = await svc.toPdf(bundle);
        if (toFile) {
          await saveBytesAs(
            fileName: '$stamp.pdf',
            bytes: pdf,
            mimeType: 'application/pdf',
          );
        } else {
          await shareBytes(fileName: '$stamp.pdf', bytes: pdf);
        }
      }
      if (mounted && toFile) showInfoSnack(context, '已保存');
    } catch (e) {
      if (mounted) showInfoSnack(context, '导出失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
    return '朝夕-月报-${fmt.format(range.from)}-${fmt.format(range.to.subtract(const Duration(days: 1)))}-$list';
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(listsProvider).value ?? const <TaskList>[];
    final isText = _format == ExportFormat.markdown;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  '导出月报',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),

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
              label: (v) => v == null
                  ? '全部'
                  : lists.firstWhere((l) => l.id == v).name,
              onSelect: (v) => setState(() => _listId = v),
            ),

            _label('要什么格式'),
            _pills<ExportFormat>(
              values: const [ExportFormat.pdf, ExportFormat.markdown],
              selected: _format,
              label: (v) => v == ExportFormat.pdf ? 'PDF 文件' : '文字（可复制）',
              onSelect: (v) => setState(() => _format = v),
            ),

            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _moreOpen = !_moreOpen),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _moreOpen ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '更多选项',
                      style: TextStyle(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            if (_moreOpen) ...[
              _label('内容'),
              _pills<ExportContent>(
                values: ExportContent.values,
                selected: _content,
                label: (v) => v.label,
                onSelect: (v) => setState(() => _content = v),
              ),
              _label('分组'),
              _pills<ExportGrouping>(
                values: ExportGrouping.values,
                selected: _grouping,
                label: (v) => v.label,
                onSelect: (v) => setState(() => _grouping = v),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeDeleted,
                onChanged: (v) =>
                    setState(() => _includeDeleted = v ?? false),
                title: const Text('包含已删除（回收站）'),
                subtitle: const Text('在报告末尾加一节「已删除」'),
              ),
            ],

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _run(toFile: false),
                icon: Icon(isText ? Icons.copy : Icons.ios_share),
                label: Text(
                  isText ? '复制文字' : '分享 / 发送',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _busy ? null : () => _run(toFile: true),
                child: Text(isText ? '存成 .md 文件…' : '存到文件夹…'),
              ),
            ),
          ],
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
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
          ChoiceChip(
            label: Text(label(v)),
            selected: v == selected,
            onSelected: (_) => onSelect(v),
          ),
      ],
    );
  }
}
