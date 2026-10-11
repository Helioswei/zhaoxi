import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/services/backup_service.dart';
import 'package:zhaoxi/services/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Directory tmp;
  late BackupService backup;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.listDao.ensureBuiltins();
    tmp = Directory.systemTemp.createTempSync('zhaoxi-backup-');
    backup = BackupService(
      db,
      ExportService(db),
      backupsDirProvider: () async => tmp,
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('backupNow 写出可解析的全量 JSON', () async {
    final file = await backup.backupNow();
    expect(file.existsSync(), isTrue);
    final content = await file.readAsString();
    expect(content, contains('"app": "zhaoxi"'));
    expect(content, contains('"tasks"'));
  });

  test('每日只自动备份一次', () async {
    final first = await backup.runIfNeeded();
    expect(first, isNotNull);
    final second = await backup.runIfNeeded();
    expect(second, isNull, reason: '今天已经备过了');
    expect((await backup.listBackups()).length, 1);
  });

  test('保留最近 N 份，多余的被清掉', () async {
    for (var i = 0; i < BackupService.keep + 3; i++) {
      final at = DateTime(2026, 10, 1).add(Duration(minutes: i));
      await backup.backupNow(now: at);
    }
    final files = await backup.listBackups();
    expect(files.length, BackupService.keep);
    // 最新的排在最前
    expect(files.first.path, contains('20261001-'));
  });
}
