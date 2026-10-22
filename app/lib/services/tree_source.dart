import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 一个可恢复的备份文件（列表里的一行）。
class BackupFileEntry {
  const BackupFileEntry({
    required this.name,
    required this.uri,
    required this.size,
    required this.modified,
    required this.folder,
  });

  final String name;
  final String uri;
  final int size;

  /// 毫秒时间戳；拿不到时为 0。
  final int modified;

  /// 相对授权目录的子路径，根目录为空串。
  final String folder;

  bool get isJson => name.toLowerCase().endsWith('.json');
}

/// 已授权的文件夹。
class AuthorizedFolder {
  const AuthorizedFolder({required this.uri, required this.name});

  final String uri;
  final String name;
}

/// 自研文件列表的数据源（方案 C）。
///
/// 只借系统界面做**一次性目录授权**，之后列表全部自己画：
/// 名字、大小、时间、搜索都不再受系统选择器渲染问题影响。
class TreeSource {
  static const _channel = MethodChannel('com.helioswei.zhaoxi/tree');

  /// 弹系统目录选择界面，返回授权结果；用户取消返回 null。
  static Future<AuthorizedFolder?> pickFolder() async {
    final raw = await _channel.invokeMethod<Object?>('openTree');
    if (raw is! Map) return null;
    final map = raw.map((k, v) => MapEntry('$k', v));
    final uri = '${map['uri'] ?? ''}';
    if (uri.isEmpty) return null;
    return AuthorizedFolder(uri: uri, name: '${map['name'] ?? '已选文件夹'}');
  }

  /// 列出目录下的 .json / .txt（含子文件夹）。
  static Future<List<BackupFileEntry>> list(String treeUri) async {
    final raw = await _channel.invokeMethod<Object?>('list', {'uri': treeUri});
    if (raw is! List) return const [];
    final out = <BackupFileEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.map((k, v) => MapEntry('$k', v));
      out.add(
        BackupFileEntry(
          name: '${map['name'] ?? ''}',
          uri: '${map['uri'] ?? ''}',
          size: (map['size'] as num?)?.toInt() ?? -1,
          modified: (map['modified'] as num?)?.toInt() ?? 0,
          folder: '${map['folder'] ?? ''}',
        ),
      );
    }
    // 新的排前面：家人最关心"我刚传进来的那份"。
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  /// 读文件内容（UTF-8，最多 4 MB）。
  static Future<String?> readText(String uri) async {
    try {
      return await _channel.invokeMethod<String>('readText', {'uri': uri});
    } on PlatformException catch (e) {
      debugPrint('readText failed: ${e.message}');
      return null;
    }
  }

  /// 在已授权文件夹的根目录里直接建一个文件（不弹系统对话框）。
  ///
  /// 失败会抛 [PlatformException]：`no_write` = 这个文件夹只授了读权限，
  /// 其他 = 写入失败（文件不存在 / 存储不可用等），由调用方翻译成人话。
  static Future<String?> createFile({
    required String treeUri,
    required String name,
    required String content,
    String mimeType = 'application/octet-stream',
  }) {
    return _channel.invokeMethod<String>('createFile', {
      'uri': treeUri,
      'name': name,
      'mime': mimeType,
      'text': content,
    });
  }

  /// 放弃某个目录的授权（换文件夹 / 授权失效时清理）。
  static Future<void> release(String treeUri) async {
    try {
      await _channel.invokeMethod<void>('release', {'uri': treeUri});
    } on PlatformException catch (e) {
      debugPrint('release tree failed: ${e.message}');
    }
  }
}
