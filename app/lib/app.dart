import 'package:flutter/material.dart';

import 'features/settings/settings_page.dart';
import 'features/task_list/task_list_page.dart';
import 'ui/theme/app_theme.dart';

/// 供通知点击后跳转使用。
final appNavigatorKey = GlobalKey<NavigatorState>();

class ZhaoxiApp extends StatelessWidget {
  const ZhaoxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '朝夕',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routes: {
        SettingsPage.routeName: (_) => const SettingsPage(),
      },
      home: const TaskListPage(),
    );
  }
}
