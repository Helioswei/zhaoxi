import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_scheduler.dart';

/// 本地通知。Android 需要 `POST_NOTIFICATIONS` + 通知渠道，
/// 精确投递还需要 `SCHEDULE_EXACT_ALARM`；被拒时降级为不精确投递（不静默失败）。
class NotificationService implements ReminderScheduler {
  NotificationService._(this._plugin);

  static final NotificationService instance =
      NotificationService._(FlutterLocalNotificationsPlugin());

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// 用户点通知时回调，参数是 taskId。
  void Function(String taskId)? onTaskTapped;

  static const channelId = 'tasks';
  static const channelName = '任务提醒';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 拿不到本地时区时退回默认（提醒时间可能偏移，但不崩）。
    }

    const settings = InitializationSettings(
      // 通知小图标必须是单色（Android 会把它当蒙版着色）；
      // 用彩色 launcher 图标会在通知栏里变成一个灰方块（T-10）。
      android: AndroidInitializationSettings('ic_notification'),
      macOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onTaskTapped?.call(payload);
        }
      },
    );

    await _ensureChannel();
    _ready = true;
  }

  /// Android 8+ 必须建渠道，否则通知不显示。
  Future<void> _ensureChannel() async {
    if (!Platform.isAndroid) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: '任务到点提醒',
        importance: Importance.high,
      ),
    );
  }

  /// 申请通知 + 精确闹钟权限。返回通知权限是否拿到。
  Future<bool> requestPermissions() async {
    var granted = true;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notifications = await android?.requestNotificationsPermission();
      if (notifications == false) granted = false;
      // 精确闹钟：Android 12+；被拒则不精确投递（见 canScheduleExact）。
      await android?.requestExactAlarmsPermission();
    } else if (Platform.isMacOS) {
      final macos = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final result = await macos?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (result == false) granted = false;
    }
    return granted;
  }

  Future<bool> notificationsEnabled() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  /// 非 Android 平台视为可用。
  Future<bool> canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<bool> schedule(
    int id,
    String title,
    DateTime when,
    String taskId,
  ) async {
    if (!_ready) return false;
    final exact = await canScheduleExact();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '任务到点提醒',
        importance: Importance.high,
        priority: Priority.high,
      ),
      macOS: DarwinNotificationDetails(),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: '到点了，别忘了 👀',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: taskId,
    );
    return true;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  /// 覆盖导入/清空数据前：取消本机全部已排程通知（避免幽灵通知）。
  Future<void> cancelAll() => _plugin.cancelAll();

  /// 应用由通知冷启动时，取出对应的 taskId。
  Future<String?> launchTaskId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }
}
