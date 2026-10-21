import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/export/backup_page.dart';
import 'features/export/export_page.dart';
import 'features/import/restore_flow.dart';
import 'features/settings/list_manage_page.dart';
import 'features/settings/recycle_bin_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/view_manage_page.dart';
import 'features/task_list/task_list_page.dart';
import 'providers/app_providers.dart';
import 'services/share_intake.dart';
import 'ui/snack.dart';
import 'ui/theme/app_theme.dart';

/// 供通知点击后跳转使用。
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 快速判断这段文本像不像朝夕的备份（避免对着一堆无关文件弹恢复窗）。
bool looksLikeZhaoxiBackup(String content) {
  try {
    final root = jsonDecode(content);
    if (root is Map && root['app'] == 'zhaoxi') return true;
  } catch (_) {
    // 不是 JSON，交给导入层去报更具体的错
  }
  return false;
}

class ZhaoxiApp extends ConsumerStatefulWidget {
  const ZhaoxiApp({super.key});

  @override
  ConsumerState<ZhaoxiApp> createState() => _ZhaoxiAppState();
}

class _ZhaoxiAppState extends ConsumerState<ZhaoxiApp>
    with WidgetsBindingObserver {
  bool _handlingShare = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ShareIntake.ensureListener();
    ShareIntake.onShare = _handleSharedFile;
    ShareIntake.onShareFailed = (name) {
      final context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      showInfoSnack(context, '读不到 $name，先把它保存到手机再试');
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleSharedFile());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从微信「分享到朝夕」回到前台时，可能带着一个备份文件。
    if (state == AppLifecycleState.resumed) _handleSharedFile();
  }

  /// 取「分享到朝夕」送来的备份文件，直接进恢复流程（不过系统选择器）。
  Future<void> _handleSharedFile() async {
    if (_handlingShare) return;
    _handlingShare = true;
    try {
      final shared = await ShareIntake.takePending();
      if (shared == null) return;
      final context = appNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;

      // 不是朝夕的备份就别弹窗了，直接说人话。
      if (!looksLikeZhaoxiBackup(shared.content)) {
        showInfoSnack(context, '这个文件不是朝夕的备份');
        return;
      }
      await showRestoreFlow(context, ref, shared.content, fileName: shared.name);
    } finally {
      _handlingShare = false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      // 中文界面：日期/时间选择器等 Material 组件也随之变中文。
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
        BackupPage.routeName: (_) => const BackupPage(),
        ViewManagePage.routeName: (_) => const ViewManagePage(),
        ListManagePage.routeName: (_) => const ListManagePage(),
        RecycleBinPage.routeName: (_) => const RecycleBinPage(),
      },
      home: const TaskListPage(),
    );
  }
}
