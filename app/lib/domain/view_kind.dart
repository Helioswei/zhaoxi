/// 8 个时间视图。顺序即默认标签栏顺序（`today` 优先，`undated` 不占 C 位）。
enum ViewKind {
  undated('undated', '待定'),
  today('today', '今天'),
  tomorrow('tomorrow', '明天'),
  week('week', '本周'),
  month('month', '本月'),
  later('later', '以后'),
  all('all', '全部'),
  done('done', '已完成');

  const ViewKind(this.id, this.label);

  final String id;
  final String label;

  /// 默认标签栏顺序（对应 `settings.view_order` 的出厂值）。
  static const List<ViewKind> defaultOrder = [
    today,
    tomorrow,
    week,
    month,
    later,
    undated,
    all,
    done,
  ];

  /// 不可隐藏的两个"安全网"视图。
  bool get isLocked => this == all || this == done;
}
