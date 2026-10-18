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

  static const keep = 7;

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
  ///
  /// **去重**：如果内容和最近一份完全一样（忽略导出时间），就不新增文件，
  /// 避免"每天开 App 就多一份一模一样的备份"。
  Future<File?> runIfNeeded({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(at);
    final last = await _db.settingsDao.get(SettingsKeys.lastBackupDate);
    if (last == today) return null;

    final json = await _export.buildBackupJson(now: at.millisecondsSinceEpoch);
    final existing = await listBackups();
    if (existing.isNotEmpty &&
        _stable(await existing.first.readAsString()) == _stable(json)) {
      await _db.settingsDao.set(SettingsKeys.lastBackupDate, today);
      return null; // 数据没变，不新增
    }

    final file = await _write(json, at);
    await _db.settingsDao.set(SettingsKeys.lastBackupDate, today);
    return file;
  }

  /// 手动「立即备份」：总是新建一份（用户主动要求的）。
  Future<File> backupNow({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final json = await _export.buildBackupJson(now: at.millisecondsSinceEpoch);
    final file = await _write(json, at);
    return file;
  }

  Future<File> _write(String json, DateTime at) async {
    final dir = await backupsDir();
    final file = File(
      p.join(dir.path, 'zhaoxi-${DateFormat('yyyyMMdd-HHmmss').format(at)}.json'),
    );
    await file.writeAsString(json, flush: true);
    await prune();
    return file;
  }

  /// 去掉「导出时间」后再比较，否则每份都会不同。
  String _stable(String json) =>
      json.replaceAll(RegExp(r'"exportedAt": \d+,'), '');

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
