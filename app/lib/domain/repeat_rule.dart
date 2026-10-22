import 'dart:convert';

/// 重复频率。
enum RepeatFreq {
  daily('每天'),
  weekly('每周'),
  monthly('每月'),
  interval('每 N 天');

  const RepeatFreq(this.label);
  final String label;
}

/// 重复规则。JSON 结构见 05 §二：
/// `{ "freq": "daily|weekly|monthly|interval", "interval": 1,
///    "byWeekday": [3], "until": null, "count": null }`
///
/// `byWeekday` 用 **1=周一 … 7=周日**，与"周界固定周一–周日"一致。
class RepeatRule {
  const RepeatRule({
    required this.freq,
    this.intervalDays = 1,
    this.byWeekday = const [],
    this.until,
    this.count,
  });

  final RepeatFreq freq;

  /// 仅 [RepeatFreq.interval] 使用：每 N 天。
  final int intervalDays;

  /// 仅 [RepeatFreq.weekly] 使用：1=周一 … 7=周日。
  final List<int> byWeekday;

  final int? until;
  final int? count;

  bool get isRepeat => true;

  // ------------------------------------------------------------ 便捷构造

  static RepeatRule daily() => const RepeatRule(freq: RepeatFreq.daily);

  static RepeatRule weekly(DateTime from) => RepeatRule(
        freq: RepeatFreq.weekly,
        byWeekday: [from.weekday],
      );

  static RepeatRule monthly() => const RepeatRule(freq: RepeatFreq.monthly);

  static RepeatRule everyDays(int days) => RepeatRule(
        freq: RepeatFreq.interval,
        intervalDays: days < 1 ? 1 : days,
      );

  // --------------------------------------------------------------- 编解码

  String encode() => jsonEncode({
        'freq': freq.name,
        'interval': intervalDays,
        if (byWeekday.isNotEmpty) 'byWeekday': byWeekday,
        if (until != null) 'until': until,
        if (count != null) 'count': count,
      });

  static RepeatRule? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final freq = RepeatFreq.values.firstWhere(
        (f) => f.name == json['freq'],
        orElse: () => RepeatFreq.daily,
      );
      final interval = (json['interval'] as num?)?.toInt() ?? 1;
      final weekdays = ((json['byWeekday'] as List?) ?? const [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((w) => w >= 1 && w <= 7)
          .toList();
      return RepeatRule(
        freq: freq,
        intervalDays: interval < 1 ? 1 : interval,
        byWeekday: weekdays,
        until: (json['until'] as num?)?.toInt(),
        count: (json['count'] as num?)?.toInt(),
      );
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ 推进

  /// 界面上的短标签：`interval` 要带上具体天数（「每 2 天」），其余直接用枚举文案。
  String get shortLabel =>
      freq == RepeatFreq.interval ? '每 $intervalDays 天' : freq.label;

  /// 从 [from] 起，**after 之后第一个**符合规则的时间点。
  ///
  /// 逾期多期不逐格补，直接跳到下一个未来点（见 02 §2.4.2）。
  DateTime advance(DateTime from, DateTime after) {
    var d = from;
    var guard = 0;
    while (!d.isAfter(after)) {
      d = _step(d);
      if (++guard > 100000) break; // 防御：规则异常时不至于死循环
    }
    return d;
  }

  /// [current] 之前的**上一个**时间点（用于"撤销完成"反推）。
  DateTime previous(DateTime current) {
    switch (freq) {
      case RepeatFreq.daily:
        return _addDays(current, -1);
      case RepeatFreq.interval:
        return _addDays(current, -intervalDays);
      case RepeatFreq.weekly:
        return _prevWeekly(current);
      case RepeatFreq.monthly:
        return _addMonths(current, -1);
    }
  }

  DateTime _step(DateTime d) {
    switch (freq) {
      case RepeatFreq.daily:
        return _addDays(d, 1);
      case RepeatFreq.interval:
        return _addDays(d, intervalDays);
      case RepeatFreq.weekly:
        return _nextWeekly(d);
      case RepeatFreq.monthly:
        return _addMonths(d, 1);
    }
  }

  DateTime _nextWeekly(DateTime d) {
    if (byWeekday.isEmpty) return _addDays(d, 7);
    for (var i = 1; i <= 7; i++) {
      final candidate = _addDays(d, i);
      if (byWeekday.contains(candidate.weekday)) return candidate;
    }
    return _addDays(d, 7);
  }

  DateTime _prevWeekly(DateTime d) {
    if (byWeekday.isEmpty) return _addDays(d, -7);
    for (var i = 1; i <= 7; i++) {
      final candidate = _addDays(d, -i);
      if (byWeekday.contains(candidate.weekday)) return candidate;
    }
    return _addDays(d, -7);
  }

  /// 保留时分；用"构造日期"而非 `Duration`，避免夏令时偏移。
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days, d.hour, d.minute);

  /// 按月推进并**夹到当月最后一天**（如 1/31 → 2/28）。
  static DateTime _addMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(year, month, day, d.hour, d.minute);
  }
}
