import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhaoxi/main.dart' as app;

/// 验收：用真实点击走一遍「新建任务」。
///
/// 定位靠控件（tooltip / 文字 / 类型），不靠坐标和截图——页面改样式、改布局
/// 都不会让这个测试失效；只有改文案或改 tooltip 才会（那种失败是显式的，该修）。
///
/// 跑法：
///   flutter drive --driver test_driver/integration_test.dart
///     --target integration_test/task_flow_test.dart -d 设备号
/// 或直接跑 `tool/acceptance/run_app_flow.sh`（它会顺手补系统侧断言）。
/// 断言（remind_at 落库、系统闹钟）在 `tool/acceptance/run_app_flow.sh` 里补，
/// 因为那两项要读数据库和系统状态，不在 App 内部。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// 不用 pumpAndSettle：输入框的光标是无限动画，settle 会超时。
  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('新建一条「明天」的任务', (tester) async {
    await app.main();
    await settle(tester, 20);

    // 1. 点右下角「+」
    final fab = find.byTooltip('新建任务（⌘N）');
    expect(fab, findsOneWidget, reason: '首页应该有新建按钮');
    await tester.tap(fab);
    await settle(tester);

    // 2. 填标题
    final title = find.byType(TextField).first;
    expect(find.text('要做什么？'), findsOneWidget, reason: '弹层应该打开了');
    await tester.tap(title);
    await settle(tester, 4);
    await tester.enterText(title, 'acceptance-notify');
    await settle(tester, 4);
    expect(find.text('acceptance-notify'), findsOneWidget,
        reason: '标题应该已经输入');

    // 3. 选「明天」
    final tomorrow = find.text('明天');
    expect(tomorrow, findsOneWidget);
    await tester.ensureVisible(tomorrow);
    await tester.tap(tomorrow);
    await settle(tester, 4);

    // 4. 保存
    final save = find.widgetWithText(FilledButton, '保存');
    expect(save, findsOneWidget);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester, 25);

    // 5. 弹层应该关掉了
    expect(find.text('要做什么？'), findsNothing, reason: '保存后弹层应该关闭');

    // 6. 切到「接下来」——任务在明天，当前「今天」视图看不到它
    final upcoming = find.text('接下来');
    expect(upcoming, findsOneWidget);
    await tester.tap(upcoming);
    await settle(tester, 6);

    expect(find.text('acceptance-notify'), findsWidgets,
        reason: '保存后「接下来」里应该出现这条任务');
  });
}
