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
  static const defaultRemindOffset = 'default_remind_offset';
  static const dateOnlyRemindTime = 'date_only_remind_time';
  static const viewOrder = 'view_order';
  static const viewHidden = 'view_hidden';
  static const viewLabels = 'view_labels';
  static const lastBackupDate = 'last_backup_date';
  static const fontScale = 'font_scale';
  static const style = 'app_style';
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
