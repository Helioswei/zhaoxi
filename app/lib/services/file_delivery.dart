import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 分享文件（移动端走系统分享面板）。
Future<void> shareBytes({
  required String fileName,
  required Uint8List bytes,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: fileName),
  );
}

/// "另存为"（移动端走 SAF，桌面走保存对话框）。返回是否保存成功。
Future<bool> saveBytesAs({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/octet-stream',
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: '保存 $fileName',
  );
  return uri != null;
}

/// 选择并读取一个 UTF-8 文本文件（用于导入备份）。
///
/// 用 `FileType.any` 而不是限定 `.json`：Android 上按 MIME 过滤时，
/// 很多文件管理器会把 JSON 标成 octet-stream/plain，导致列表里看不到目录与文件名。
/// 选完再由 ImportService 校验内容。
Future<String?> pickTextFile() async {
  final files = await FilePicker.pickFiles(
    type: FileType.any,
    dialogTitle: '选择备份文件',
  );
  if (files.isEmpty) return null;
  return files.first.xFile.readAsString();
}
