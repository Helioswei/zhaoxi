import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 「分享到朝夕」收到的文件。
class SharedFile {
  const SharedFile({required this.name, required this.content});

  final String name;
  final String content;
}

/// 接收「分享到朝夕」送来的备份文件。
///
/// 为什么需要它：部分机型（小米等）的系统文件选择器不显示文件名，
/// 家人根本分不清哪个才是备份；分享进来就完全绕开那个界面。
class ShareIntake {
  static const _channel = MethodChannel('com.helioswei.zhaoxi/share');

  /// 原生收到分享后主动通知（App 在前台时用得上）。
  static void Function()? onShare;

  /// 收到了文件但读不出来（对方没给读取权限）。
  static void Function(String name)? onShareFailed;

  static bool _hooked = false;

  /// 挂一次原生→Flutter 的推送回调。
  static void ensureListener() {
    if (_hooked) return;
    _hooked = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShare') {
        onShare?.call();
      } else if (call.method == 'onShareFailed') {
        final args = call.arguments;
        final name = args is Map ? '${args['name'] ?? ''}' : '';
        onShareFailed?.call(name.isEmpty ? '这个文件' : name);
      }
    });
  }

  /// 取走待处理的分享文件；没有则返回 null。
  static Future<SharedFile?> takePending() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('takePendingShare');
      if (raw is! Map) return null;
      final map = raw.map((k, v) => MapEntry('$k', v));
      final content = '${map['content'] ?? ''}';
      if (content.isEmpty) return null;
      return SharedFile(name: '${map['name'] ?? '共享文件'}', content: content);
    } on PlatformException catch (e) {
      debugPrint('takePendingShare failed: ${e.message}');
      return null;
    }
  }
}
