import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/domain/view_config.dart';
import 'package:zhaoxi/domain/view_kind.dart';

void main() {
  test('默认配置：8 个视图全部可见，顺序 = today 优先', () {
    final c = ViewConfig.defaults();
    expect(c.visible, ViewKind.defaultOrder);
    expect(c.visible.first, ViewKind.today);
    expect(c.visible.last, ViewKind.done);
    expect(c.labelOf(ViewKind.week), '本周');
  });

  test('隐藏 / 重命名 编解码往返一致', () {
    final c = ViewConfig.defaults()
        .copyWith(hidden: {ViewKind.later}, labels: {ViewKind.week: '这周'});
    final decoded = ViewConfig.decode(
      orderJson: c.encodeOrder(),
      hiddenJson: c.encodeHidden(),
      labelsJson: c.encodeLabels(),
    );
    expect(decoded.isHidden(ViewKind.later), isTrue);
    expect(decoded.labelOf(ViewKind.week), '这周');
    expect(decoded.visible.contains(ViewKind.later), isFalse);
  });

  test('锁定的「全部 / 已完成」即使写进 JSON 也不会被隐藏', () {
    final decoded = ViewConfig.decode(
      hiddenJson: '["all","done","later"]',
    );
    expect(decoded.isHidden(ViewKind.all), isFalse);
    expect(decoded.isHidden(ViewKind.done), isFalse);
    expect(decoded.isHidden(ViewKind.later), isTrue);
  });

  test('顺序里缺失的视图会被补齐（版本升级不丢视图）', () {
    final decoded = ViewConfig.decode(orderJson: '["today","done"]');
    expect(decoded.order.length, ViewKind.values.length);
    expect(decoded.order.first, ViewKind.today);
    for (final v in ViewKind.values) {
      expect(decoded.order.contains(v), isTrue, reason: '缺少 $v');
    }
  });

  test('损坏的 JSON 回退到默认', () {
    final decoded = ViewConfig.decode(
      orderJson: 'not json',
      hiddenJson: '{{{',
      labelsJson: 'nope',
    );
    expect(decoded.order, ViewKind.defaultOrder);
    expect(decoded.hidden, isEmpty);
    expect(decoded.labels, isEmpty);
  });
}
