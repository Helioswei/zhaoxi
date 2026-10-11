import 'package:flutter/material.dart';

import 'features/task_list/task_list_page.dart';
import 'ui/theme/app_theme.dart';

class ZhaoxiApp extends StatelessWidget {
  const ZhaoxiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '朝夕',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const TaskListPage(),
    );
  }
}
