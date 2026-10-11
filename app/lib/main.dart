import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.open();
  // 首启补齐内置清单（工作 / 生活），只补缺失的，不覆盖用户改动。
  await db.listDao.ensureBuiltins();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const ZhaoxiApp(),
    ),
  );
}
