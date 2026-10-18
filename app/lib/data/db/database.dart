import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dao/list_dao.dart';
import '../dao/settings_dao.dart';
import '../dao/task_dao.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Tasks, TaskLists, SettingsEntries],
  daos: [TaskDao, ListDao, SettingsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// 打开应用目录下的 `zhaoxi.db`。
  AppDatabase.open() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2：取消「待定」——把所有无日期的任务落到“今天”（数据不丢）。
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day)
                .millisecondsSinceEpoch;
            await customStatement(
              'UPDATE tasks SET due_at = ?, due_has_time = 0 WHERE due_at IS NULL',
              [todayStart],
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'zhaoxi.db'));
    return NativeDatabase.createInBackground(file);
  });
}
