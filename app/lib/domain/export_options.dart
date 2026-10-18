import 'day_boundary.dart';

/// 导出范围预设。默认「本月」（写月报，见 02 §2.6）。
enum ExportRangePreset {
  thisWeek('本周'),
  thisMonth('本月'),
  lastWeek('上周'),
  lastMonth('上月'),
  custom('自定义');

  const ExportRangePreset(this.label);
  final String label;
}

enum ExportContent {
  doneOnly('仅已完成'),
  doneAndOpen('已完成 + 未完成');

  const ExportContent(this.label);
  final String label;
}

enum ExportGrouping {
  week('按周'),
  day('按日'),
  none('不分组');

  const ExportGrouping(this.label);
  final String label;
}

enum ExportFormat {
  pdf('PDF'),
  word('Word'),
  xlsx('Excel'),
  markdown('Markdown'),
  text('文字');

  const ExportFormat(this.label);
  final String label;

  /// 需要生成文件（否则是复制到剪贴板）。
  bool get isFile => this != ExportFormat.text;
}

/// 一次导出的参数：范围 × 清单 × 内容 × 分组。
class ExportOptions {
  const ExportOptions({
    this.preset = ExportRangePreset.thisMonth,
    this.content = ExportContent.doneOnly,
    this.grouping = ExportGrouping.week,
    this.format = ExportFormat.markdown,
    this.listId,
    this.includeDeleted = false,
    this.customFrom,
    this.customTo,
  });

  final ExportRangePreset preset;
  final ExportContent content;
  final ExportGrouping grouping;
  final ExportFormat format;

  /// null = 全部清单。
  final String? listId;

  /// 是否在 Markdown / PDF 末尾追加「已删除（回收站）」章节。
  final bool includeDeleted;

  final DateTime? customFrom;
  final DateTime? customTo;

  /// 「月报」预设：本月 + 工作 + 仅已完成 + 按周 + Markdown。
  static ExportOptions monthlyReport({String? workListId}) => ExportOptions(
        preset: ExportRangePreset.thisMonth,
        content: ExportContent.doneOnly,
        grouping: ExportGrouping.week,
        format: ExportFormat.pdf,
        listId: workListId,
      );

  ExportOptions copyWith({
    ExportRangePreset? preset,
    ExportContent? content,
    ExportGrouping? grouping,
    ExportFormat? format,
    Object? listId = _sentinel,
    bool? includeDeleted,
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    return ExportOptions(
      preset: preset ?? this.preset,
      content: content ?? this.content,
      grouping: grouping ?? this.grouping,
      format: format ?? this.format,
      listId: listId == _sentinel ? this.listId : listId as String?,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      customFrom: customFrom ?? this.customFrom,
      customTo: customTo ?? this.customTo,
    );
  }

  static const _sentinel = Object();

  /// 计算 [from, to)（本地时区）。
  ({DateTime from, DateTime to}) resolveRange([DateTime? now]) {
    final b = DayBounds(now);
    switch (preset) {
      case ExportRangePreset.thisWeek:
        return (from: b.weekStart, to: b.nextWeekStart);
      case ExportRangePreset.thisMonth:
        return (from: b.monthStart, to: b.nextMonthStart);
      case ExportRangePreset.lastWeek:
        final start = b.weekStart.subtract(const Duration(days: 7));
        return (
          from: DateTime(start.year, start.month, start.day),
          to: b.weekStart,
        );
      case ExportRangePreset.lastMonth:
        return (
          from: DateTime(b.monthStart.year, b.monthStart.month - 1, 1),
          to: b.monthStart,
        );
      case ExportRangePreset.custom:
        final from = customFrom ?? b.monthStart;
        var to = customTo ?? b.nextMonthStart;
        // 结束日含当天 → 取次日 00:00
        to = DateTime(to.year, to.month, to.day + 1);
        return (from: DateTime(from.year, from.month, from.day), to: to);
    }
  }

  /// 报告标题里的期间描述，如「2026 年 10 月」。
  String periodLabel([DateTime? now]) {
    final range = resolveRange(now);
    switch (preset) {
      case ExportRangePreset.thisMonth:
      case ExportRangePreset.lastMonth:
        return '${range.from.year} 年 ${range.from.month} 月';
      default:
        return '${_fmt(range.from)} ~ ${_fmt(DateTime(range.to.year, range.to.month, range.to.day - 1))}';
    }
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
