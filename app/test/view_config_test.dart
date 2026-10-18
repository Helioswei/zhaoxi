import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/view_config.dart';
import 'package:zhaoxi/domain/view_kind.dart';

void main() {
  test('默认配置：只显示 今天 / 接下来 / 已完成，「全部」默认隐藏', () {
    final c = ViewConfig.defaults();
    expect(c.visible, [ViewKind.today, ViewKind.upcoming, ViewKind.done]);
    expect(c.isHidden(ViewKind.all), isTrue);
    expect(c.order.length, ViewKind.values.length);
    expect(c.labelOf(ViewKind.upcoming), '接下来');
  });

  test('隐藏 / 重命名 编解码往返一致', () {
    final c = ViewConfig.defaults()
        .copyWith(hidden: {ViewKind.all}, labels: {ViewKind.upcoming: '往后'});
    final decoded = ViewConfig.decode(
      orderJson: c.encodeOrder(),
      hiddenJson: c.encodeHidden(),
      labelsJson: c.encodeLabels(),
    );
    expect(decoded.isHidden(ViewKind.all), isTrue);
    expect(decoded.labelOf(ViewKind.upcoming), '往后');
    expect(decoded.visible, isNot(contains(ViewKind.all)));
  });

  test('锁定的「今天 / 已完成」即使写进 JSON 也不会被隐藏', () {
    final decoded = ViewConfig.decode(
      hiddenJson: '["today","done","upcoming"]',
    );
    expect(decoded.isHidden(ViewKind.today), isFalse);
    expect(decoded.isHidden(ViewKind.done), isFalse);
    expect(decoded.isHidden(ViewKind.upcoming), isTrue);
  });

  test('顺序里缺失的视图会被补齐（版本升级不丢视图）', () {
    final decoded = ViewConfig.decode(orderJson: '["today","done"]');
    expect(decoded.order.length, ViewKind.values.length);
    for (final v in ViewKind.values) {
      expect(decoded.order.contains(v), isTrue, reason: '缺少 $v');
    }
  });

  test('损坏的 JSON 回退到默认（「全部」仍隐藏）', () {
    final decoded = ViewConfig.decode(
      orderJson: 'not json',
      hiddenJson: '{{{',
      labelsJson: 'nope',
    );
    expect(decoded.order, ViewKind.defaultOrder);
    expect(decoded.isHidden(ViewKind.all), isTrue);
    expect(decoded.labels, isEmpty);
  });
}
