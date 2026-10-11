import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/dao/settings_dao.dart';
import '../data/db/database.dart';
import 'export_service.dart';

/// 每日自动备份（全量 JSON），保留最近 [keep] 份。
///
/// 备份落在应用私有目录 `…/backups/`，**不需要任何权限**；
/// 想看/取走文件请用「导出」（系统分享 / 另存为）。
class BackupService {
  BackupService(
    this._db,
    this._export, {
    Future<Directory> Function()? backupsDirProvider,
  }) : _dirProvider = backupsDirProvider ?? _defaultDir;

  final AppDatabase _db;
  final ExportService _export;
  final Future<Directory> Function() _dirProvider;

  static const keep = 14;

  static Future<Directory> _defaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> backupsDir() => _dirProvider();

  /// 最近的备份在前。
  Future<List<File>> listBackups() async {
    final dir = await backupsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// 每天首次启动备份一次；今天已备份过则返回 null。
  Future<File?> runIfNeeded({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(at);
    final last = await _db.settingsDao.get(SettingsKeys.lastBackupDate);
    if (last == today) return null;
    final file = await backupNow(now: at);
    await _db.settingsDao.set(SettingsKeys.lastBackupDate, today);
    return file;
  }

  Future<File> backupNow({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final json = await _export.buildBackupJson();
    final dir = await backupsDir();
    final file = File(
      p.join(dir.path, 'zhaoxi-${DateFormat('yyyyMMdd-HHmmss').format(at)}.json'),
    );
    await file.writeAsString(json, flush: true);
    await prune();
    return file;
  }

  /// 只保留最近 [keep] 份。
  Future<void> prune() async {
    final files = await listBackups();
    for (final f in files.skip(keep)) {
      try {
        await f.delete();
      } catch (_) {
        // 删不掉就算了，不阻塞
      }
    }
  }
}
