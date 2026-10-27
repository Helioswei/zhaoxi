import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/features/task_list/task_list_page.dart';

/// 回归：长按拖拽时跟随手指的那张卡片不能变样。
///
/// 默认实现会套一层不透明 Material + elevation 6，卡片圆角、奶油底色都会没了，
/// 实测反馈「长按移动后样式变了，不好看」。
void main() {
  testWidgets('拖拽代理：透明底、轻投影、保留原卡片', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: taskDragProxy(
            const SizedBox(key: ValueKey('card'), width: 200, height: 60),
            const AlwaysStoppedAnimation<double>(1),
            22,
          ),
        ),
      ),
    );

    // 原卡片必须还在（不能替换成别的盒子）
    expect(find.byKey(const ValueKey('card')), findsOneWidget);

    final material = tester.widget<Material>(
      find.byKey(const ValueKey('drag-proxy')),
    );
    expect(material.color, Colors.transparent,
        reason: '不能盖不透明底色，否则卡片就是一块白板');
    expect(material.elevation, lessThanOrEqualTo(2),
        reason: '默认的 elevation 6 太重，违背平面优先');

    final transform = tester.widget<Transform>(find.byType(Transform).first);
    final scale = transform.transform.getMaxScaleOnAxis();
    expect(scale, closeTo(1.015, 0.001), reason: '只做很轻的放大');
  });
}
