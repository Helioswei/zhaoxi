import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/export/export_page.dart';
import 'features/settings/list_manage_page.dart';
import 'features/settings/recycle_bin_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/view_manage_page.dart';
import 'features/task_list/task_list_page.dart';
import 'providers/app_providers.dart';
import 'ui/theme/app_theme.dart';

/// 供通知点击后跳转使用。
final appNavigatorKey = GlobalKey<NavigatorState>();

class ZhaoxiApp extends ConsumerWidget {
  const ZhaoxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    final style = ref.watch(styleProvider);

    return MaterialApp(
      title: '朝夕',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(style: style, brightness: Brightness.light),
      darkTheme: buildAppTheme(style: style, brightness: Brightness.dark),
      themeMode: mode,
      // 字号：在系统缩放基础上再乘一个系数（大字号无障碍）。
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final systemFactor = mq.textScaler.scale(10) / 10;
        final factor = fontScale == 'large' ? 1.2 : 1.0;
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(systemFactor * factor),
          ),
          child: child!,
        );
      },
      routes: {
        SettingsPage.routeName: (_) => const SettingsPage(),
        ExportPage.routeName: (_) => const ExportPage(),
        ViewManagePage.routeName: (_) => const ViewManagePage(),
        ListManagePage.routeName: (_) => const ListManagePage(),
        RecycleBinPage.routeName: (_) => const RecycleBinPage(),
      },
      home: const TaskListPage(),
    );
  }
}
