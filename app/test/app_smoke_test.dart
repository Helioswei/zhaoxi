import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/app.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/domain/view_config.dart';
import 'package:zhaoxi/providers/app_providers.dart';

/// 测试用：跳过从数据库读设置。
class _NoDbThemeMode extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

class _NoDbViewConfig extends ViewConfigNotifier {
  @override
  ViewConfig build() => ViewConfig.defaults();
}

class _NoDbRemindOffset extends RemindOffsetNotifier {
  @override
  int build() => 0;
}

class _NoDbFontScale extends FontScaleNotifier {
  @override
  String build() => 'normal';
}

/// 纯 UI 冒烟测试：用 provider 覆盖喂数据，不触碰真实数据库
/// （Drift 的真实异步在 widget test 的 fake-async 下不会按时完成）。
Widget _app({
  List<Task> tasks = const [],
  int undated = 0,
  List<TaskList> lists = const [],
}) {
  return ProviderScope(
    overrides: [
      taskListProvider.overrideWith((ref) => Stream.value(tasks)),
      listsProvider.overrideWith((ref) => Stream.value(lists)),
      undatedCountProvider.overrideWith((ref) => Stream.value(undated)),
      themeModeProvider.overrideWith(_NoDbThemeMode.new),
      viewConfigProvider.overrideWith(_NoDbViewConfig.new),
      remindOffsetProvider.overrideWith(_NoDbRemindOffset.new),
      fontScaleProvider.overrideWith(_NoDbFontScale.new),
    ],
    child: const ZhaoxiApp(),
  );
}

void main() {
  testWidgets('首页渲染 8 个视图 + 空状态', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('朝夕'), findsOneWidget);
    for (final label in ['待定', '今天', '明天', '本周', '本月', '以后', '全部', '已完成']) {
      expect(find.widgetWithText(ChoiceChip, label), findsWidgets,
          reason: '缺少视图标签：$label');
    }
    expect(find.text('今天没有安排 🎉'), findsOneWidget);
  });

  testWidgets('清单筛选栏渲染内置清单', (tester) async {
    await tester.pumpWidget(_app(lists: const [
      TaskList(
        id: 'list-work',
        name: '工作',
        color: '#3B6EA5',
        sortOrder: 0,
        isBuiltin: true,
        deleted: false,
        updatedAt: 0,
        originDevice: 'test',
      ),
    ]));
    await tester.pumpAndSettle();

    // “工作”只在清单筛选栏出现；“全部”两栏都有（清单筛选 + 视图栏）
    expect(find.widgetWithText(ChoiceChip, '工作'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '全部'), findsWidgets);
  });

  testWidgets('「待定」汇总提示：点击后切到待定视图并隐藏横幅', (tester) async {
    await tester.pumpWidget(_app(undated: 2));
    await tester.pumpAndSettle();

    expect(find.text('还有 2 件没定时间'), findsOneWidget);
    await tester.tap(find.text('还有 2 件没定时间'));
    await tester.pumpAndSettle();

    // 切走后横幅不再出现（它只在「今天」显示）
    expect(find.text('还有 2 件没定时间'), findsNothing);
    expect(find.text('都安排好了 👌'), findsOneWidget);
  });

  testWidgets('点 ＋ 打开新建弹层', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('新建任务'), findsOneWidget);

    // 标题为空时不允许保存
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('写点什么呢？'), findsOneWidget);
  });
}
