import 'dart:convert';

import 'view_kind.dart';

/// 视图的用户配置：顺序 / 隐藏 / 重命名（US-028）。
/// [ViewKind.all] 与 [ViewKind.done] 为安全网，不允许隐藏。
class ViewConfig {
  const ViewConfig({
    required this.order,
    required this.hidden,
    required this.labels,
  });

  final List<ViewKind> order;
  final Set<ViewKind> hidden;
  final Map<ViewKind, String> labels;

  factory ViewConfig.defaults() => const ViewConfig(
        order: ViewKind.defaultOrder,
        hidden: {},
        labels: {},
      );

  List<ViewKind> get visible =>
      order.where((v) => !hidden.contains(v)).toList(growable: false);

  String labelOf(ViewKind v) => labels[v] ?? v.label;

  bool isHidden(ViewKind v) => hidden.contains(v);

  /// 锁定项（全部 / 已完成）不可隐藏。
  bool canHide(ViewKind v) => !v.isLocked;

  ViewConfig copyWith({
    List<ViewKind>? order,
    Set<ViewKind>? hidden,
    Map<ViewKind, String>? labels,
  }) =>
      ViewConfig(
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
        labels: labels ?? this.labels,
      );

  String encodeOrder() => jsonEncode(order.map((v) => v.id).toList());
  String encodeHidden() => jsonEncode(hidden.map((v) => v.id).toList());
  String encodeLabels() => jsonEncode(
        {for (final e in labels.entries) e.key.id: e.value},
      );

  static ViewConfig decode({
    String? orderJson,
    String? hiddenJson,
    String? labelsJson,
  }) {
    final byId = {for (final v in ViewKind.values) v.id: v};

    List<ViewKind> order = ViewKind.defaultOrder;
    try {
      final raw = jsonDecode(orderJson ?? '') as List;
      final parsed = raw
          .map((e) => byId[e as String?])
          .whereType<ViewKind>()
          .toList();
      // 补齐缺失项（版本升级新增视图时不丢）
      for (final v in ViewKind.values) {
        if (!parsed.contains(v)) parsed.add(v);
      }
      if (parsed.isNotEmpty) order = parsed;
    } catch (_) {
      // 用默认顺序
    }

    Set<ViewKind> hidden = {};
    try {
      final raw = jsonDecode(hiddenJson ?? '') as List;
      hidden = raw
          .map((e) => byId[e as String?])
          .whereType<ViewKind>()
          .where((v) => v.canHide)
          .toSet();
    } catch (_) {
      // ignore
    }

    Map<ViewKind, String> labels = {};
    try {
      final raw = jsonDecode(labelsJson ?? '') as Map;
      raw.forEach((k, v) {
        final kind = byId[k as String?];
        if (kind != null && v is String && v.trim().isNotEmpty) {
          labels[kind] = v;
        }
      });
    } catch (_) {
      // ignore
    }

    return ViewConfig(order: order, hidden: hidden, labels: labels);
  }
}
