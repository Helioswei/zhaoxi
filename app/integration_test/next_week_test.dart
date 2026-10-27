import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhaoxi/main.dart' as app;

/// 回归：周五（任意 weekday）点「下周」，任务不能落到过去的日期。
///
/// 之前的 bug：`下周` 用的是**本周**周一，周五点它就落到周一（过去），
/// 任务一建出来就显示成逾期。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('选「下周」得到下周一，不会落到过去', (tester) async {
    await app.main();
    await settle(tester, 20);

    // 期望值：本周一 + 7 天
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final nextMonday = DateTime(monday.year, monday.month, monday.day + 7);
    final expectedLabel = '${nextMonday.month}月${nextMonday.day}日';

    await tester.tap(find.byTooltip('新建任务（⌘N）'));
    await settle(tester);

    await tester.tap(find.byType(TextField).first);
    await settle(tester, 4);
    await tester.enterText(find.byType(TextField).first, 'acceptance-nextweek');
    await settle(tester, 4);

    final nextWeek = find.text('下周');
    expect(nextWeek, findsOneWidget);
    await tester.ensureVisible(nextWeek);
    await tester.tap(nextWeek);
    await settle(tester, 6);

    // 弹层里的摘要应该已经显示下周一
    expect(find.textContaining(expectedLabel), findsWidgets,
        reason: '选了「下周」，摘要应该是下周一 $expectedLabel');

    final save = find.widgetWithText(FilledButton, '保存');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester, 20);

    // 切到「接下来」看这条任务，日期标签必须是下周一（不是逾期）
    await tester.tap(find.text('接下来'));
    await settle(tester, 8);
    expect(find.text('acceptance-nextweek'), findsWidgets,
        reason: '任务应该在「接下来」里');
    expect(find.text(expectedLabel), findsWidgets,
        reason: '日期标签应该是 $expectedLabel');
  });
}
