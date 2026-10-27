# 朝夕 — 技术架构

> 版本：v0.5
> 日期：2026-10-12
> 状态：待评审（已吸收评审意见 + 真实使用场景补充）
> 已决策：Flutter（Android + macOS）／Drift + SQLite／本地存储／暂不做同步

---

## 一、技术栈

| 层面 | 选择 | 理由 |
|---|---|---|
| **框架** | Flutter（stable） | 一套代码覆盖 Android + macOS；与 yijing-app 同栈 |
| **本地数据库** | **Drift**（SQLite 之上） | 类型安全、可写 SQL、支持迁移；`sqlite3_flutter_libs` 提供全平台原生库 |
| **状态管理** | **Riverpod** | 轻量、可测试（若要与 yijing-app 一致则用 Provider，二选一在 M0 定） |
| **路由** | `Navigator` + 少量命名路由 | 页面少，无需 go_router |
| **本地通知** | `flutter_local_notifications` + `timezone` + `flutter_timezone` | 定时投递；需本地时区；无需服务器 |
| **导出 PDF** | `pdf` + `printing` | 纯 Dart 生成；`printing` 提供保存/分享 |
| **文件/分享** | `share_plus`、`file_picker`、`path_provider` | **导出落盘到用户可见位置的关键** |
| **权限** | `permission_handler` | 麦克风、通知、精确闹钟 |
| **文本** | `characters`（Flutter 内置） | 按字素簇计数 |
| **日期** | `intl`、`table_calendar`（可选） | 格式化与日期选择 |

### 明确不用

| 不用 | 原因 |
|---|---|
| 任何后端 / 云服务 | 纯本地，无同步 |
| Hive | 需要按截止时间/状态筛选排序，SQLite 更合适 |
| 第三方 ASR SDK | 成本与隐私；系统识别已够用 |

---

## 二、架构分层

采用**轻量四层 + 一个纯逻辑域**：

```
┌────────────────────────────────────────────────┐
│  UI 层 (features/)                              │
│  页面 / 弹层 / 组件 / 主题                        │
└───────────────┬────────────────────────────────┘
                │ 观察状态、调用方法
┌───────────────▼────────────────────────────────┐
│  状态层 (providers/)                             │
│  任务列表、筛选、表单、设置                        │
└───────────────┬────────────────────────────────┘
                │
        ┌───────┴────────┐
        ▼                ▼
┌───────────────┐  ┌──────────────────────────────┐
│  服务层        │  │  数据层 (data/)               │
│  services/     │─▶│  Drift 数据库 + DAO + Repo    │
│  通知/导出/     │  │  （唯一直接读写 DB 的地方）     │
│  导出/备份      │  └──────────────────────────────┘
└───────────────┘
        ▲
        │ 依赖
┌───────┴────────────────────────────────────────┐
│  领域层 (domain/) —— 纯 Dart，无 Flutter 依赖     │
│  模型 / 重复规则算法 / 时间边界计算                │
└────────────────────────────────────────────────┘
```

**依赖方向（不可反向）**：

| 层 | 可以依赖 | 不可以依赖 |
|---|---|---|
| UI | 状态层、域模型 | 数据库、服务实现 |
| 状态层 | 服务层、数据层 | UI |
| 服务层 | 数据层、领域层 | UI、状态层 |
| 数据层 | 领域层 | 服务层、UI |
| 领域层 | 无（纯函数/模型） | 任何其他层 |

> 修正点：**服务层依赖数据层**（备份/导出要读库，通知要读任务），原图箭头方向反了，已改正。

---

## 三、目录结构

```
zhaoxi/
├── docs/
├── app/
│   ├── lib/
│   │   ├── main.dart              # 入口：DB、通知、时区初始化
│   │   ├── app.dart               # MaterialApp、主题、本地化
│   │   ├── data/
│   │   │   ├── db/{database.dart, tables.dart, database.g.dart}
│   │   │   ├── dao/{task_dao.dart, list_dao.dart}
│   │   │   └── repo/{task_repository.dart, list_repository.dart}
│   │   ├── domain/                # 纯 Dart
│   │   │   ├── models/task.dart
│   │   │   ├── day_boundary.dart  # 本地时区日界计算
│   │   │   ├── repeat_rule.dart   # 重复规则（P1）
│   │   │   └── date_parser.dart   # 自然语言时间（P2）
│   │   ├── features/
│   │   │   ├── task_list/         # 首页 + 视图切换 + 清单筛选 + 条目
│   │   │   ├── task_edit/         # 新建/编辑/详情（同一弹层）
│   │   │   ├── list_manage/       # 清单管理（工作/生活）
│   │   │   ├── settings/          # 含视图管理
│   │   │   └── export/
│   │   ├── services/
│   │   │   ├── notification_service.dart
│   │   │   ├── export_service.dart
│   │   │   └── backup_service.dart
│   │   ├── providers/
│   │   ├── ui/{theme/, widgets/}
│   │   └── l10n/
│   ├── android/
│   ├── macos/
│   ├── assets/fonts/              # ZhaoxiSerif-Regular.ttf（思源宋体 TrueType 子集）+ OFL.txt（必须随包）
│   └── test/                      # 单测：重复规则、时区边界、导入导出往返
└── README.md
```

---

## 四、数据存储与路径

- 引擎：SQLite（`sqlite3_flutter_libs`）。
- 表：`tasks` / `lists` / `settings`（见 [05](./05-数据模型-DATA-MODEL.md)）。
- 位置：`getApplicationDocumentsDirectory()/zhaoxi.db`
  - Android：`/data/data/<pkg>/app_flutter/`（**应用私有，其他 App 读不到**）
  - macOS：沙盒容器内 Documents
- 迁移：Drift `schemaVersion`（记作 **`dbSchemaVersion`**）+ `MigrationStrategy`，每次改表写迁移脚本。
- 事务：所有写操作包在事务里。
- 破坏性迁移前自动导出一份全量 JSON 保底：**优先写用户备份目录；未设置或 macOS bookmark 未授权时写应用私有目录，并显式提示**（不静默失败）。

> ⚠️ **数据库文件绝不放进云盘目录同步**（将来做同步时也一样）：WAL、半写入会导致损坏。同步走"变更序列化"而非文件复制。

### 4.1 导出为什么必须走系统面板（P0）

私有目录里的文件用户拿不到 → 等价于没导出。所以：

| 平台 | 落盘方式 |
|---|---|
| Android | `share_plus` 分享面板，或 `file_picker.saveFile`（SAF）让用户选位置 |
| macOS | `printing`/`file_picker` 触发 `NSSavePanel` |

三种格式（PDF/MD/JSON）生成在临时目录后，**一律走上面的面板**，这是 P0 验收项。

---

## 五、权限清单

### 5.1 Android

| 权限 | 声明位置 | 时机 | 降级 |
|---|---|---|---|
| `POST_NOTIFICATIONS` | Manifest | 首次排程提醒 | 提示条引导开启 |
| `SCHEDULE_EXACT_ALARM` | Manifest | 首次排程精确提醒，跳系统设置 | 用 `AndroidScheduleMode.inexactAllowWhileIdle` |
| `RECEIVE_BOOT_COMPLETED` | Manifest | 安装即声明 | 重启后由 App 启动时重排 |

**通知渠道**：`main.dart` 初始化时创建，id=`tasks`，importance high。**API 26+ 不建渠道则通知不显示。**

**精确闹钟**：`flutter_local_notifications` 提供 `requestExactAlarmsPermission()`（Android 12+）；调用前用 `canScheduleExactAlarms()` 判断，拒了就降级并**在设置页显式标注**。

### 5.2 macOS 沙盒与权限

macOS 沙盒下，`Info.plist` 声明**不够**，还必须在 `*.entitlements` 打开对应能力：

| 文件 | 键 | 用途 |
|---|---|---|
| `DebugProfile.entitlements` / `Release.entitlements` | `com.apple.security.app-sandbox` | 沙盒（默认开） |
| 同上 | `com.apple.security.files.user-selected.read-write` | 用户选定的导出/备份目录 |
| 同上 | `com.apple.security.files.bookmarks.app-scope` | 持久化目录授权 |

`Info.plist` **不需要**麦克风 / 语音识别描述（语音输入已于 2026-10-18 移除）。

**目录授权（security-scoped bookmark）**——这是必踩坑：

```
用户选目录 → 生成 bookmark → base64 存 settings.backup_dir_bookmark
每次读写前：resolveBookmarkData() → startAccessingSecurityScopedResource()
          → 读/写 → stopAccessingSecurityScopedResource()
重启 App 后必须走这套，否则写入静默失败
```

`settings.backup_dir` 只作为展示用路径，真正授权以 bookmark 为准。

### 5.3 离线保证（由 CI 守住）

「数据不出本机」不能只写在文档里，已经落成可执行的检查：

| 层 | 现状 | 谁在守 |
|---|---|---|
| Android release 权限 | 只有 `POST_NOTIFICATIONS` / `SCHEDULE_EXACT_ALARM` / `RECEIVE_BOOT_COMPLETED`（外加通知库自带的 `VIBRATE`），**没有 `INTERNET` / `ACCESS_NETWORK_STATE`** | `tool/check_offline.sh`，android job 每次构建后跑 |
| macOS release entitlements | 沙盒 + 用户所选文件读写 + bookmark，**没有 `network.client` / `network.server`** | 同一脚本的静态检查 |
| Dart 代码与依赖 | 无 http / dio / socket / analytics；`pubspec.yaml` 里没有联网包 | 人工评审 + 依赖审查 |

> `android/app/src/debug|profile/AndroidManifest.xml` 里的 `INTERNET` 是 Flutter 调试工具链（热重载 / DevTools）要的，**不会进 release 包**；`DebugProfile.entitlements` 里的 `network.server` 同理，只服务本机调试连接。

自查：

```bash
cd app
REQUIRE_APK=1 tool/check_offline.sh   # 非 0 退出 = 有人加了网络权限
```

CI 里这一步失败会直接标红并挡住 artifact 上传，所以"哪天顺手引入联网"不会悄悄发生。

---

## 六、时区与"今天"的日界（高频出错点）

1. **存储**：`due_at`、`remind_at` 一律 **UTC 毫秒**。
2. **日界**：所有"今天/明天"在**本地时区**算，再转 UTC 比较：

```
本地明天 00:00  →  DateTime(now.year, now.month, now.day).add(1 天)
                →  取该本地时刻对应的 UTC 毫秒  →  与 due_at 比较
```

东八区下，"本地明天 00:00" = "今天 16:00 UTC"，直接拿 UTC 日期比较会错一天。
所有这类计算集中在 `domain/day_boundary.dart`，禁止散落各处。

3. **日期型任务**：`due_has_time = 0` 时，`due_at` = 本地当天 00:00 的 UTC 值；默认 `remind_at` = 本地当天 09:00（设置可改，已过则不排）。
4. 初始化：`main()` 里 `tz.initializeTimeZones()` + `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`，否则 `zonedSchedule` 定时不准。

---

## 七、语音输入（已取消）

2026-10-18 移除。原因：Android 上依赖系统 `SpeechRecognizer`（不少国产 ROM 没有），
且 `initialize()` 在无服务时会抛异常。现已删除 `speech_to_text`、`permission_handler` 依赖，
并从 Manifest 去掉 `RECORD_AUDIO` / `INTERNET` 与识别服务可见性，App 变为**纯离线**。

## 八、提醒通知

| 项 | 方案 |
|---|---|
| 排程 | `zonedSchedule` + `AndroidScheduleMode.exactAllowWhileIdle`；不可用时降级 `inexactAllowWhileIdle` |
| 通知 ID | **`tasks.notif_id`（自增整数，来自 settings 计数器）**，不用 UUID 哈希（Android ID 是 32 位 int，哈希会碰撞） |
| 渠道 | Android 启动建 `tasks` 渠道（importance high） |
| 保存任务 | 取消旧通知 → 未完成且有提醒时间 → 排新通知 |
| 完成/删除 | 取消通知 |
| 撤销完成/撤销删除 | `remind_at` 在未来 → 重排；已过 → 不排并提示 |
| 重复任务 | **原地推进**（US-019）：完成后取消旧通知、把 `due_at` 推到下一次、排下一次；**不用** `matchDateTimeComponents` |
| 重启（Android） | App 启动时扫描未来 `remind_at` 重排 |
| 导入覆盖 | **先取消本机全部已排程通知**，导入完成后再按新数据重排 |

---

## 九、导出与备份

| 格式 | 实现 | 要点 |
|---|---|---|
| **JSON** | `jsonEncode` | **全量备份（忽略导出范围）**；含 `exportFormatVersion`；**不含 `deviceId`**；导入校验 + 合并/覆盖；**绝不覆盖 `device_id` / 视图配置** |
| **Markdown** | 字符串拼接 | **按周分节**；`- [x] 标题（10.02）`，备注缩进 `> `；可选"未完成/结转"章节；Obsidian 兼容。模板见 [02 §5.2](./02-需求规格-REQUIREMENTS.md) |
| **PDF** | `pdf` 包 | 打包思源宋体；**与 Markdown 同一套排版** |
| **范围/清单过滤** | `export_service` | 范围（本周/本月/上周/上月/自定义）× 清单 × 内容 × 分组；**「月报」预设** = 本月+工作+仅已完成+按周+Markdown |
| **落盘** | `share_plus` / `file_picker` | 见 §4.1，P0 |
| **自动备份** | `backup_service` | 每日首启写全量 JSON（**与上一份相同则跳过**）；保留 7 份；列表可分享/恢复 |

**相关实现落点**

- **视图管理**：`view_order` / `view_hidden` / `view_labels` 存 `settings`，由 `task_list` 读取；锁定 `all` / `done`（见 05 §四）。
- **清单**：内置 `list-work` / `list-life` 固定 id（见 05 §三）；`list_dao` 管理；首页清单筛选叠加在视图查询之上。
- **字体许可**：PDF 用的思源宋体子集 `ZhaoxiSerif-Regular.ttf` 采用 **SIL OFL-1.1**，随包附带 `OFL.txt`，并在「关于 → 开源许可」中列出。字体由 `tool/build_pdf_font.py` 生成（完整 OTF → 字符子集 → TrueType，因为 `pdf` 包只支持 glyf 轮廓）。

### 9.1 版本号要分两个

| 版本 | 含义 | 变化时机 |
|---|---|---|
| `dbSchemaVersion` | Drift 数据库结构版本 | 每次改表 +1 |
| `exportFormatVersion` | 导出 JSON 的**格式**版本 | 仅当导出结构变化时 +1 |

**导入规则**：

| 情况 | 行为 |
|---|---|
| `exportFormatVersion` > 当前 | 拒绝，提示"备份来自更新版本" |
| `< 当前` | 走**导出格式升级路径**（逐版本迁移函数），不拒绝 |
| 缺字段 | 用默认值补齐 |
| 合并 | 按 `id` 匹配，`updated_at` 大者胜；不改设置、**不覆盖 `device_id`** |
| 覆盖 | 清空 `tasks` / `lists` 再写入（二次确认）；**不覆盖 `device_id` / `notif_id_counter` / 视图配置** |

> 原稿把两个版本混用一个 `schemaVersion`，会导致"改一次数据库结构 → 所有旧备份被误判为更新版本而拒绝"。已拆分。

---

## 十、为未来同步预留（本期不实现）

先把将来同步的成本降到最低，代价几乎为零：

1. **主键用 UUID**；2. **每行带 `updated_at` 与 `deleted`**；3. **每行带 `origin_device`**；4. **读写集中在 Repository**。

将来接入：导出/合并 JSON 到 WebDAV（坚果云）或共享云盘文件夹；合并策略 `id` 匹配 → `updated_at` 大者胜 → 平局用 `origin_device` 打破。触发：启动、回前台、手动下拉。

> **前提**：`device_id` 在每台设备上独立且**永不被导入覆盖**，否则平局兜底失效（见 05 §五）。

---

## 十一、排序与数值边界

- `sort_order` 用 REAL，拖拽时取相邻两值中点。连续拖拽约 50 次后 double 精度耗尽、相邻值会相等 → **当 `abs(a-b) < 1e-6` 时触发整表重排（renormalize，重新分配 1024/2048/3072…）**。放在 `task_dao` 里，插入逻辑内自动检查。

---

## 十二、打包与分发

### Android 本地打包（固定文件名，永远覆盖最新）

```bash
cd app
flutter build apk --release --split-per-abi   # 日常真机测试（arm64 约 24 MB）
flutter build apk --release                   # 通用包：含全部 ABI，约 70 MB
```

**一条命令（推荐）**：

```bash
cd app
./tool/build_release.sh            # 构建 + 校验（图标资源、离线权限）
./tool/build_release.sh --smoke    # 再装到设备上确认能进首页
```

脚本会依次做：`pub get`（构建不带 `--no-pub`）→ 构建 → **校验 APK 里真有
`ic_notification`** → 离线守卫 → （`--smoke`）装机启动并扫未捕获异常。
两道校验都是踩过坑才加的，见 `tool/build_release.sh` 顶部注释。

产物固定在 `app/build/app/outputs/flutter-apk/`，名字由 Flutter 决定：

| 文件 | 用途 |
|---|---|
| `app-arm64-v8a-release.apk` | 主流真机，**日常测试下这个** |
| `app-armeabi-v7a-release.apk` | 老 32 位机型 |
| `app-x86_64-release.apk` | 模拟器 |
| `app-release.apk` | 通用包（只在没带 `--split-per-abi` 时产出） |

**命名规则**

1. **不重命名、不加日期、不复制副本。** 每次构建同名覆盖，所以下载地址永久不变，手机上收藏一次即可。
2. 构建会顺带生成同名 `.sha1`（40 位十六进制、无换行，内容就是该 APK 的 SHA-1），随包自动刷新，不手工维护。
3. 只有要留旧版做对比时才归档，且**用版本号命名，不用日期**——同一天重打两次，带日期反而分不清：

   ```bash
   mkdir -p archive
   cp app-arm64-v8a-release.apk "archive/zhaoxi-1.0.0+2001-arm64.apk"
   ```

**versionCode 注意（换包类型会踩）**

- 通用包：等于 `pubspec.yaml` 里的 build number（`version: 1.0.0+1` → `1`）。
- `--split-per-abi` 会按 ABI 加偏移：armeabi-v7a `1001` / arm64-v8a `2001` / x86_64 `4001`。
- 所以**先装 split 包、再装回通用包会被当成降级而装不上**（2001 → 1）。测试阶段固定用同一种包；确实要换，先导出 JSON 备份 → 卸载 → 装新包 → 导入。

**手机下载**

本机在产物目录起静态服务，手机连同一个 Wi-Fi：

```bash
cd app/build/app/outputs/flutter-apk
python3 -m http.server 8899 --bind 0.0.0.0
```

手机浏览器打开 `http://<本机 IP>:8899/app-arm64-v8a-release.apk`。该服务会给正确的 MIME（`application/vnd.android.package-archive`），点开即安装；侧载需允许「未知来源」。覆盖安装的前提是签名与已装版本一致（见下节）。

### Android 签名

- 本地：`app/android/key.properties`（已 gitignore）指向 `~/AIWork/.zhaoxi-signing/zhaoxi-release.jks`；
- CI：secrets `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`；
- 未配置时退回 debug 签名（仅够自测）。
- ⚠️ **换签名后旧版无法覆盖安装**：先导出 JSON → 卸载 → 装新版 → 导入。

### macOS

```bash
flutter build macos --release        # build/macos/Build/Products/Release/*.app
```
未签名首次打开：右键 → 打开，或 `xattr -dr com.apple.quarantine <app>`。要省事可本地 ad-hoc 签名。

### 图标 / 启动页

`flutter_launcher_icons` + `flutter_native_splash`。

---

## 十三、测试策略

| 层级 | 测什么 |
|---|---|
| 单元测试 | **时区日界计算**（东八区跨日）、重复规则、导出/导入往返一致、视图筛选与排序、`exportFormatVersion` 升降级、sort_order 重排 |
| Widget 测试 | 新建流程、完成/撤销、空状态、标题字素簇上限 |
| 手动测试清单 | 通知到点是否触发（真机）、Android 14 精确闹钟授权流程、导出文件能打开、macOS 备份目录重启后仍可写、杀进程后数据仍在 |

`flutter analyze` 必须零 warning。

---

## 十四、开发环境

已验证本机具备：Flutter + Dart、Android SDK + adb。

缺失需补：**Xcode**（macOS 桌面构建必需）、**CocoaPods**。
建议在 **M0 期间就顺手跑通一次 macOS 构建**，避免 M4 集中踩坑。
