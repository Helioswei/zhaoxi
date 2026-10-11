import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/export/export_page.dart';
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

    return MaterialApp(
      title: '朝夕',
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: mode,
      routes: {
        SettingsPage.routeName: (_) => const SettingsPage(),
        ExportPage.routeName: (_) => const ExportPage(),
        ViewManagePage.routeName: (_) => const ViewManagePage(),
      },
      home: const TaskListPage(),
    );
  }
}
