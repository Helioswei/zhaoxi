import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/app.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/domain/view_config.dart';
import 'package:zhaoxi/providers/app_providers.dart';
import 'package:zhaoxi/ui/theme/app_style.dart';
import 'package:zhaoxi/ui/widgets/app_pill.dart';

/// 测试用：跳过从数据库读设置。
class _NoDbStyle extends StyleNotifier {
  @override
  AppStyleId build() => AppStyleId.warm;
}

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

Widget _app({
  List<Task> tasks = const [],
  List<TaskList> lists = const [],
}) {
  return ProviderScope(
    overrides: [
      taskListProvider.overrideWith((ref) => Stream.value(tasks)),
      listsProvider.overrideWith((ref) => Stream.value(lists)),
      searchResultsProvider.overrideWith((ref) => Stream.value(const [])),
      themeModeProvider.overrideWith(_NoDbThemeMode.new),
      viewConfigProvider.overrideWith(_NoDbViewConfig.new),
      remindOffsetProvider.overrideWith(_NoDbRemindOffset.new),
      fontScaleProvider.overrideWith(_NoDbFontScale.new),
      styleProvider.overrideWith(_NoDbStyle.new),
    ],
    child: const ZhaoxiApp(),
  );
}

void main() {
  testWidgets('首页只有 3 个视图：今天 / 接下来 / 已完成', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('朝夕'), findsOneWidget);
    for (final label in ['今天', '接下来', '已完成']) {
      expect(find.widgetWithText(AppPill, label), findsWidgets,
          reason: '缺少视图标签：$label');
    }
    // 「全部」默认隐藏
    expect(find.widgetWithText(AppPill, '全部'), findsOneWidget,
        reason: '「全部」只应出现在清单筛选栏，不应出现在视图栏');
    expect(find.text('今天没有安排'), findsOneWidget);
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

    expect(find.widgetWithText(AppPill, '工作'), findsOneWidget);
    expect(find.widgetWithText(AppPill, '全部'), findsOneWidget);
  });

  testWidgets('切到「接下来」显示对应空状态', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppPill, '接下来'));
    await tester.pumpAndSettle();
    expect(find.text('接下来没有安排'), findsOneWidget);
  });

  testWidgets('点 ＋ 打开新建弹层；空标题不允许保存', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('新建任务'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('写点什么呢？'), findsOneWidget);

    // 提示条带兜底定时器，排空后再结束测试。
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
  });
}
