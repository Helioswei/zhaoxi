import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zhaoxi/main.dart' as app;

/// 验收：备份页的三条路——立即备份、从本机备份恢复、存到已授权文件夹。
///
/// 只看界面（Snackbar 文案）；「文件真的落盘了吗」「数据库条数变没变」由
/// `tool/acceptance/run_backup_flow.sh` 在 App 外面查。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Snackbar 会排队、几秒后自动消失，固定 pump 很容易错过；
  /// 改成轮询到出现为止。
  Future<void> waitFor(WidgetTester tester, Finder finder, String reason,
      {int seconds = 15}) async {
    for (var i = 0; i < seconds * 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail(reason);
  }

  testWidgets('备份页：立即备份 / 恢复 / 存到文件夹', (tester) async {
    await app.main();
    await settle(tester, 20);

    // 设置 → 备份与恢复
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await settle(tester);
    final entry = find.text('备份与恢复');
    expect(entry, findsOneWidget, reason: '设置里应该有备份入口');
    await tester.tap(entry);
    await settle(tester, 14);

    // 1. 立即备份
    final backupNow = find.text('立即备份');
    expect(backupNow, findsOneWidget);
    await tester.ensureVisible(backupNow);
    await tester.tap(backupNow);
    await waitFor(tester, find.textContaining('已备份到本机'), '立即备份应该有成功提示');

    // 2. 从本机备份恢复（第一条）
    final restore = find.text('恢复').first;
    expect(restore, findsOneWidget);
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await settle(tester, 10);
    expect(find.text('怎么恢复？'), findsOneWidget, reason: '应该弹出恢复方式');
    await tester.tap(find.text('合并'));
    await waitFor(tester, find.textContaining('已导入'), '合并恢复应该有导入结果');

    // 3. 存到已授权文件夹（没授权就跳过——授权要走系统目录选择器，测试驱动不了）
    final saveTo = find.textContaining('存到「');
    if (saveTo.evaluate().isEmpty) {
      markTestSkipped('还没授权备份文件夹，跳过「存到文件夹」');
      return;
    }
    await tester.ensureVisible(saveTo.first);
    await tester.tap(saveTo.first);
    await waitFor(tester, find.textContaining('已保存到'), '存到文件夹应该有成功提示');
  });
}
