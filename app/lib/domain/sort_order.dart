/// `sort_order` 用 REAL，拖拽时取相邻两值的中点。
///
/// 连续拖拽约 50 次后 double 精度会耗尽、相邻值相等 →
/// 当间距小于 [kRenormalizeEpsilon] 时触发整表重排（renormalize）。
const double kSortStep = 1024;
const double kRenormalizeEpsilon = 1e-6;

/// 计算插入到 [before] 与 [after] 之间的新排序值。
/// 两侧都为 null 表示不知道相邻项，返回 null（调用方保持原值）。
double? sortOrderBetween(double? before, double? after) {
  if (before == null && after == null) return null;
  if (before == null) return after! - kSortStep;
  if (after == null) return before + kSortStep;
  return (before + after) / 2;
}

/// 间距过小、需要整表重排。
bool needsRenormalize(double? before, double? after) =>
    before != null &&
    after != null &&
    (after - before).abs() < kRenormalizeEpsilon;

/// 按给定顺序重新分配排序值：1024, 2048, 3072 …
Map<String, double> renormalized(Iterable<String> idsInOrder) {
  final result = <String, double>{};
  var i = 1;
  for (final id in idsInOrder) {
    result[id] = kSortStep * i;
    i++;
  }
  return result;
}
