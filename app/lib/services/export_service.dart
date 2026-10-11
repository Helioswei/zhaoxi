import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/db/database.dart';
import '../data/json/backup_json.dart';
import '../domain/export_options.dart';

class ExportBundle {
  ExportBundle({
    required this.options,
    required this.done,
    required this.open,
    required this.lists,
    required this.from,
    required this.to,
  });

  final ExportOptions options;
  final List<Task> done;
  final List<Task> open;
  final Map<String, TaskList> lists;
  final DateTime from;
  final DateTime to;

  bool get isEmpty => done.isEmpty && open.isEmpty;
}

/// 导出：范围过滤 + Markdown/PDF 排版 + 全量 JSON 备份。
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  static Future<pw.Font> _serifFont() async {
    final data = await rootBundle.load('assets/fonts/ZhaoxiSerif-Regular.ttf');
    return pw.Font.ttf(data);
  }

  Future<ExportBundle> collectRange(ExportOptions options,
      {DateTime? now}) async {
    final range = options.resolveRange(now);
    final fromMs = range.from.millisecondsSinceEpoch;
    final toMs = range.to.millisecondsSinceEpoch;

    var done = await _db.taskDao.completedBetween(fromMs, toMs);
    var open = options.content == ExportContent.doneAndOpen
        ? await _db.taskDao.openDueBetween(fromMs, toMs)
        : <Task>[];

    if (options.listId != null) {
      done = done.where((t) => t.listId == options.listId).toList();
      open = open.where((t) => t.listId == options.listId).toList();
    }

    final lists = <String, TaskList>{
      for (final l in await _db.listDao.getAll()) l.id: l,
    };

    return ExportBundle(
      options: options,
      done: done,
      open: open,
      lists: lists,
      from: range.from,
      to: range.to,
    );
  }

  // ---------------------------------------------------------------- Markdown

  String toMarkdown(ExportBundle b, {DateTime? now}) {
    final sb = StringBuffer();
    sb.writeln('# ${_title(b)}');
    sb.writeln('> 范围：${_d(b.from)} ~ ${_d(_lastDay(b.to))}'
        ' ｜ 清单：${_listLabel(b)}'
        ' ｜ 导出：${_dt(now ?? DateTime.now())}');
    sb.writeln();

    sb.writeln('## 已完成（${b.done.length} 项）');
    sb.writeln();
    _writeGrouped(sb, b, b.done, completed: true);

    if (b.open.isNotEmpty) {
      sb.writeln('## 未完成 / 结转（${b.open.length} 项）');
      sb.writeln();
      _writeGrouped(sb, b, b.open, completed: false);
    }
    return sb.toString();
  }

  void _writeGrouped(
    StringBuffer sb,
    ExportBundle b,
    List<Task> tasks, {
    required bool completed,
  }) {
    if (tasks.isEmpty) {
      sb.writeln('_（没有记录）_');
      sb.writeln();
      return;
    }
    final sorted = [...tasks]..sort((x, y) =>
        _stamp(x, completed).compareTo(_stamp(y, completed)));

    String? currentKey;
    for (final t in sorted) {
      final stamp = _stamp(t, completed);
      final key = _groupKey(b, b.options.grouping, stamp);
      if (key != null && key != currentKey) {
        sb.writeln('### $key');
        currentKey = key;
      }
      final mark = completed ? 'x' : ' ';
      sb.writeln('- [$mark] ${t.title}（${_d(DateTime.fromMillisecondsSinceEpoch(stamp))}）');
      if ((t.note ?? '').isNotEmpty) {
        sb.writeln('  > ${t.note}');
      }
    }
    sb.writeln();
  }

  // --------------------------------------------------------------------- PDF

  Future<Uint8List> toPdf(ExportBundle b, {DateTime? now}) async {
    final font = await _serifFont();
    final doc = pw.Document();

    final theme = pw.ThemeData.withFont(base: font, bold: font);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(_title(b),
                style: pw.TextStyle(font: font, fontSize: 20)),
          ),
          pw.Text(
            '范围：${_d(b.from)} ~ ${_d(_lastDay(b.to))}　清单：${_listLabel(b)}'
            '　导出：${_dt(now ?? DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Text('已完成（${b.done.length} 项）',
              style: pw.TextStyle(font: font, fontSize: 14)),
          pw.SizedBox(height: 6),
          ..._pdfGrouped(b, b.done, completed: true, font: font),
          if (b.open.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text('未完成 / 结转（${b.open.length} 项）',
                style: pw.TextStyle(font: font, fontSize: 14)),
            pw.SizedBox(height: 6),
            ..._pdfGrouped(b, b.open, completed: false, font: font),
          ],
        ],
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _pdfGrouped(
    ExportBundle b,
    List<Task> tasks, {
    required bool completed,
    required pw.Font font,
  }) {
    if (tasks.isEmpty) {
      return [
        pw.Text('（没有记录）',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
      ];
    }
    final sorted = [...tasks]..sort((x, y) =>
        _stamp(x, completed).compareTo(_stamp(y, completed)));
    final widgets = <pw.Widget>[];
    String? currentKey;
    for (final t in sorted) {
      final stamp = _stamp(t, completed);
      final key = _groupKey(b, b.options.grouping, stamp);
      if (key != null && key != currentKey) {
        widgets.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
          child: pw.Text(key,
              style: pw.TextStyle(
                  font: font, fontSize: 12, color: PdfColors.grey800)),
        ));
        currentKey = key;
      }
      widgets.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 14,
              child: pw.Text(
                completed ? '✓' : '○',
                style: pw.TextStyle(font: font, fontSize: 11),
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      '${t.title}（${_d(DateTime.fromMillisecondsSinceEpoch(stamp))}）',
                      style: pw.TextStyle(font: font, fontSize: 11)),
                  if ((t.note ?? '').isNotEmpty)
                    pw.Text(t.note!,
                        style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  // -------------------------------------------------------------------- JSON

  /// 全量备份，忽略范围/清单/分组（JSON 恒为全量，见 02 §2.6）。
  Future<String> buildBackupJson({int? now}) async {
    final tasks = await _db.taskDao.allForBackup();
    final lists = await _db.listDao.allForBackup();
    final payload = <String, dynamic>{
      'app': kAppTag,
      'exportFormatVersion': kExportFormatVersion,
      'dbSchemaVersion': _db.schemaVersion,
      'exportedAt': now ?? DateTime.now().millisecondsSinceEpoch,
      'taskCount': tasks.length,
      'lists': lists.map(listToJson).toList(),
      'tasks': tasks.map(taskToJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  // ------------------------------------------------------------------ 辅助

  int _stamp(Task t, bool completed) =>
      (completed ? t.completedAt : t.dueAt) ?? t.createdAt;

  String? _groupKey(ExportBundle b, ExportGrouping grouping, int stampMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(stampMs);
    switch (grouping) {
      case ExportGrouping.none:
        return null;
      case ExportGrouping.day:
        return '${d.month} 月 ${d.day} 日';
      case ExportGrouping.week:
        // 按自然周（周一~周日）分组，但**裁到报告范围内**，
        // 周序号从报告起始周算起（月报里就是“本月第 N 周”）。
        final monday = DateTime(d.year, d.month, d.day - (d.weekday - 1));
        final sunday = DateTime(monday.year, monday.month, monday.day + 6);
        final rangeStart = b.from;
        final rangeWeekStart = DateTime(rangeStart.year, rangeStart.month,
            rangeStart.day - (rangeStart.weekday - 1));
        final index = monday.difference(rangeWeekStart).inDays ~/ 7 + 1;
        final lastDay = DateTime(b.to.year, b.to.month, b.to.day - 1);
        final clipStart = monday.isBefore(rangeStart) ? rangeStart : monday;
        final clipEnd = sunday.isAfter(lastDay) ? lastDay : sunday;
        return '${clipStart.month} 月第 $index 周'
            '（${_md(clipStart)}–${_md(clipEnd)}）';
    }
  }

  String _title(ExportBundle b) =>
      '${_listLabel(b)} · ${b.options.periodLabel()}';

  String _listLabel(ExportBundle b) {
    if (b.options.listId == null) return '记录';
    return b.lists[b.options.listId]?.name ?? '记录';
  }

  static String _d(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String _dt(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d);
  static String _md(DateTime d) => DateFormat('MM.dd').format(d);
  static DateTime _lastDay(DateTime to) => DateTime(to.year, to.month, to.day - 1);
}

/// 便于 UI 显示"将导出 N 条"。
extension ExportBundleSummary on ExportBundle {
  String get summary {
    final parts = <String>['${done.length} 项已完成'];
    if (open.isNotEmpty) parts.add('${open.length} 项未完成');
    return parts.join(' + ');
  }
}
