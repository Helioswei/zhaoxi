import 'package:integration_test/integration_test_driver.dart';

/// `flutter drive` 的驱动入口。
///
/// 用 drive 而不是 test：`flutter test integration_test` 跑完会把 App 卸载，
/// 之后就查不到数据库和系统闹钟了；drive 装完会保留。
Future<void> main() => integrationDriver();
