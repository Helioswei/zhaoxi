import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhaoxi/main.dart' as app;

/// 回归：两个实测反馈——
/// 1. 「加一个具体时间」不该是转圆盘：先给常用时间点，自定义才进输入模式；
/// 2. 列表不能整张卡片直接拖（上滑看内容会变成移动任务），要长按才拖。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('时间选择：先点常用时间，不是转圆盘', (tester) async {
    await app.main();
    await settle(tester, 20);

    await tester.tap(find.byTooltip('新建任务（⌘N）'));
    await settle(tester);

    final addTime = find.text('加一个具体时间');
    expect(addTime, findsOneWidget);
    await tester.ensureVisible(addTime);
    await tester.tap(addTime);
    await settle(tester, 8);

    expect(find.text('几点？'), findsOneWidget, reason: '应该弹出常用时间');
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);

    await tester.tap(find.text('09:00'));
    await settle(tester, 8);
    expect(find.textContaining('09:00'), findsWidgets,
        reason: '选完应该显示 09:00');
  });

  testWidgets('列表要长按才进入拖拽', (tester) async {
    await app.main();
    await settle(tester, 20);

    // 列表为空就没有拖拽组件，先建一条
    await tester.tap(find.byTooltip('新建任务（⌘N）'));
    await settle(tester);
    await tester.tap(find.byType(TextField).first);
    await settle(tester, 4);
    await tester.enterText(find.byType(TextField).first, 'acceptance-drag');
    await settle(tester, 4);
    final save = find.widgetWithText(FilledButton, '保存');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester, 20);

    // 整卡直接拖会让「上滑」变成「移动任务」，必须用延迟版的拖拽监听。
    expect(find.byType(ReorderableDelayedDragStartListener), findsWidgets,
        reason: '任务卡应该用长按拖拽');
    expect(find.byType(ReorderableDragStartListener), findsNothing,
        reason: '不能用「一拖就排序」的版本');
  });
}
