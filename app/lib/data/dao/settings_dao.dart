import 'package:drift/drift.dart';

import '../db/database.dart';
import '../db/tables.dart';

part 'settings_dao.g.dart';

/// `settings` 键值表的读取入口。
class SettingsKeys {
  static const deviceId = 'device_id';
  static const notifIdCounter = 'notif_id_counter';
  static const themeMode = 'theme_mode';
  static const lastUsedList = 'last_used_list';
}

@DriftAccessor(tables: [SettingsEntries])
class SettingsDao extends DatabaseAccessor<AppDatabase> with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<String?> get(String key) async {
    final row = await (select(settingsEntries)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String? value) {
    return into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(
        key: key,
        value: Value(value),
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
