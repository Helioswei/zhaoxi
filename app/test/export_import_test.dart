import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhaoxi/data/db/database.dart';
import 'package:zhaoxi/data/json/backup_json.dart' show kExportFormatVersion;
import 'package:zhaoxi/domain/export_options.dart';
import 'package:zhaoxi/services/export_service.dart';
import 'package:zhaoxi/services/import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExportService export;
  late ImportService importer;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.listDao.ensureBuiltins();
    export = ExportService(db);
    importer = ImportService(db);
  });

  tearDown(() => db.close());

  Future<String> addTask({
    required String id,
    required String title,
    required String listId,
    int? completedAt,
    int? dueAt,
    String? note,
    int? updatedAt,
  }) async {
    final now = updatedAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.taskDao.upsert(
      TasksCompanion.insert(
        id: id,
        title: title,
        listId: listId,
        note: Value(note),
        dueAt: Value(dueAt),
        status: Value(completedAt != null ? 1 : 0),
        completedAt: Value(completedAt),
        createdAt: now,
        updatedAt: now,
        originDevice: 'test-device',
      ),
    );
    return id;
  }

  final now = DateTime(2026, 10, 15, 12);
  final inMonth = DateTime(2026, 10, 10, 9).millisecondsSinceEpoch;
  final lastMonth = DateTime(2026, 9, 20, 9).millisecondsSinceEpoch;

  test('范围过滤：只取本月完成的事项', () async {
    await addTask(id: 'a', title: '本月完成', listId: 'list-work', completedAt: inMonth);
    await addTask(id: 'b', title: '上月完成', listId: 'list-work', completedAt: lastMonth);

    final bundle = await export.collectRange(
      const ExportOptions(preset: ExportRangePreset.thisMonth),
      now: now,
    );
    expect(bundle.done.map((t) => t.title), ['本月完成']);
  });

  test('清单过滤：月报只要工作', () async {
    await addTask(id: 'a', title: '工作事', listId: 'list-work', completedAt: inMonth);
    await addTask(id: 'b', title: '生活事', listId: 'list-life', completedAt: inMonth);

    final bundle = await export.collectRange(
      ExportOptions(preset: ExportRangePreset.thisMonth, listId: 'list-work'),
      now: now,
    );
    expect(bundle.done.map((t) => t.title), ['工作事']);
  });

  test('未完成章节：内容选 doneAndOpen 时按 dueAt 纳入', () async {
    await addTask(id: 'a', title: '做完了', listId: 'list-work', completedAt: inMonth);
    await addTask(id: 'b', title: '还没做', listId: 'list-work', dueAt: inMonth);

    final bundle = await export.collectRange(
      const ExportOptions(
        preset: ExportRangePreset.thisMonth,
        content: ExportContent.doneAndOpen,
      ),
      now: now,
    );
    expect(bundle.done.length, 1);
    expect(bundle.open.map((t) => t.title), ['还没做']);
  });

  test('Markdown：按周分节 + 勾选状态 + 备注缩进 + 未完成章节', () async {
    await addTask(
      id: 'a',
      title: '完成方案评审',
      listId: 'list-work',
      completedAt: DateTime(2026, 10, 2, 10).millisecondsSinceEpoch,
      note: '与 A 方确认预算',
    );
    await addTask(
      id: 'b',
      title: '合同盖章',
      listId: 'list-work',
      dueAt: DateTime(2026, 10, 28, 9).millisecondsSinceEpoch,
    );

    final bundle = await export.collectRange(
      const ExportOptions(
        preset: ExportRangePreset.thisMonth,
        content: ExportContent.doneAndOpen,
        grouping: ExportGrouping.week,
        listId: 'list-work',
      ),
      now: now,
    );
    final md = export.toMarkdown(bundle, now: now);

    expect(md, contains('# 工作 · 2026 年 10 月'));
    expect(md, contains('## 已完成（1 项）'));
    expect(md, contains('### 10 月第 1 周（10.01–10.04）'));
    expect(md, contains('- [x] 完成方案评审（2026-10-02）'));
    expect(md, contains('  > 与 A 方确认预算'));
    expect(md, contains('## 未完成 / 结转（1 项）'));
    expect(md, contains('- [ ] 合同盖章（2026-10-28）'));
  });

  test('PDF：能生成非空字节（含中文字体）', () async {
    await addTask(id: 'a', title: '中文标题测试', listId: 'list-work', completedAt: inMonth);
    final bundle = await export.collectRange(
      const ExportOptions(preset: ExportRangePreset.thisMonth),
      now: now,
    );
    final bytes = await export.toPdf(bundle, now: now);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('JSON 全量备份：含格式版本、不含 deviceId', () async {
    await addTask(id: 'a', title: '备份项', listId: 'list-work', completedAt: inMonth);
    final json = await export.buildBackupJson();
    final root = jsonDecode(json) as Map<String, dynamic>;

    expect(root['app'], 'zhaoxi');
    expect(root['exportFormatVersion'], kExportFormatVersion);
    expect(root['taskCount'], 1);
    expect(json.contains('deviceId'), isFalse);
    expect((root['lists'] as List).length, 2);
  });

  test('合并导入：本地较新的记录被跳过', () async {
    await addTask(id: 'a', title: '本地版本', listId: 'list-work', updatedAt: 2000);
    final backup = jsonEncode({
      'app': 'zhaoxi',
      'exportFormatVersion': 1,
      'tasks': [
        {
          'id': 'a',
          'title': '备份里的旧版本',
          'listId': 'list-work',
          'updatedAt': 1000,
          'createdAt': 1000,
        },
      ],
      'lists': <Map<String, dynamic>>[],
    });

    final result = await importer.importJson(backup, overwrite: false);
    expect(result.tasksImported, 0);
    expect(result.tasksSkipped, 1);
    expect((await db.taskDao.findById('a'))!.title, '本地版本');
  });

  test('合并导入：本地没有则新增，并自动补清单', () async {
    final backup = jsonEncode({
      'app': 'zhaoxi',
      'exportFormatVersion': 1,
      'tasks': [
        {
          'id': 'new-1',
          'title': '新来的',
          'listId': 'list-work',
          'createdAt': 1000,
          'updatedAt': 1000,
        },
      ],
      'lists': <Map<String, dynamic>>[],
    });

    final result = await importer.importJson(backup, overwrite: false);
    expect(result.tasksImported, 1);
    expect((await db.taskDao.findById('new-1'))!.title, '新来的');
  });

  test('覆盖导入：清空后写入', () async {
    await addTask(id: 'old', title: '旧数据', listId: 'list-work');
    final backup = jsonEncode({
      'app': 'zhaoxi',
      'exportFormatVersion': 1,
      'tasks': [
        {
          'id': 'only',
          'title': '唯一',
          'listId': 'list-work',
          'createdAt': 1000,
          'updatedAt': 1000,
        },
      ],
      'lists': [
        {'id': 'list-work', 'name': '工作', 'updatedAt': 1},
      ],
    });

    await importer.importJson(backup, overwrite: true);
    expect(await db.taskDao.findById('old'), isNull);
    expect((await db.taskDao.findById('only'))!.title, '唯一');
  });

  test('覆盖导入：任务引用了不存在的清单 → 判为文件损坏', () async {
    final broken = jsonEncode({
      'app': 'zhaoxi',
      'exportFormatVersion': 1,
      'tasks': [
        {'id': 'x', 'title': 'x', 'listId': 'missing-list'},
      ],
      'lists': [
        {'id': 'list-work', 'name': '工作'},
      ],
    });

    expect(
      () => importer.importJson(broken, overwrite: true),
      throwsA(isA<ImportException>()),
    );
  });

  test('导入校验：非本 App / 更高版本都拒绝', () async {
    expect(
      () => importer.importJson('{"app":"other"}', overwrite: false),
      throwsA(isA<ImportException>()),
    );
    expect(
      () => importer.importJson(
        '{"app":"zhaoxi","exportFormatVersion":99}',
        overwrite: false,
      ),
      throwsA(isA<ImportException>()),
    );
    expect(
      () => importer.importJson('not json', overwrite: false),
      throwsA(isA<ImportException>()),
    );
  });
}
