import 'day_boundary.dart';
import 'view_kind.dart';

/// 一次视图查询的参数：时间视图 + 清单筛选（两者正交）。
class TaskFilter {
  const TaskFilter({required this.view, required this.bounds, this.listId});

  final ViewKind view;
  final DayBounds bounds;

  /// null = 全部清单。
  final String? listId;
}
