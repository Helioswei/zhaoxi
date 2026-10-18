/// 视图（时间维度）。默认只显示三个：今天 / 接下来 / 已完成。
///
/// - 今天：逾期 + 今天到期
/// - 接下来：明天及以后，按「明天 / 本周 / 本月 / 更远」分组
/// - 已完成：做过的
/// - 全部：默认隐藏（高级用法 / 安全网）
enum ViewKind {
  today('today', '今天'),
  upcoming('upcoming', '接下来'),
  done('done', '已完成'),
  all('all', '全部');

  const ViewKind(this.id, this.label);

  final String id;
  final String label;

  /// 标签栏默认顺序；`all` 默认隐藏（见 [ViewConfig]）。
  static const List<ViewKind> defaultOrder = [today, upcoming, done, all];

  /// 不可隐藏的视图：今天（核心）、已完成（历史）。
  bool get isLocked => this == today || this == done;

  bool get canHide => !isLocked;
}
