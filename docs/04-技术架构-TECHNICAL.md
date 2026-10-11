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
| **语音识别** | `speech_to_text` | 调用各平台**系统**识别，不自建 ASR |
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
│  语音/通知/     │  │  （唯一直接读写 DB 的地方）     │
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
todo-app/
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
│   │   │   ├── task_list/         # 首页 + 视图切换 + 清单筛选 + 条目 + 快捷语音
│   │   │   ├── task_edit/         # 新建/编辑/详情（同一弹层）
│   │   │   ├── list_manage/       # 清单管理（工作/生活）
│   │   │   ├── settings/          # 含视图管理
│   │   │   └── export/
│   │   ├── services/
│   │   │   ├── speech_service.dart
│   │   │   ├── notification_service.dart
│   │   │   ├── export_service.dart
│   │   │   └── backup_service.dart
│   │   ├── providers/
│   │   ├── ui/{theme/, widgets/}
│   │   └── l10n/
│   ├── android/
│   ├── macos/
│   ├── assets/fonts/              # SourceHanSerifCN（PDF 用）+ OFL.txt（必须随包）
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
| `INTERNET` | Manifest | 安装即声明（语音需要） | 无网时语音不可用 |
| `RECORD_AUDIO`（麦克风） | Manifest（运行时） | 首次语音 | 提示手动输入 |

**通知渠道**：`main.dart` 初始化时创建，id=`tasks`，importance high。**API 26+ 不建渠道则通知不显示。**

**精确闹钟**：`flutter_local_notifications` 提供 `requestExactAlarmsPermission()`（Android 12+）；调用前用 `canScheduleExactAlarms()` 判断，拒了就降级并**在设置页显式标注**。

### 5.2 macOS 沙盒与权限

macOS 沙盒下，`Info.plist` 声明**不够**，还必须在 `*.entitlements` 打开对应能力：

| 文件 | 键 | 用途 |
|---|---|---|
| `DebugProfile.entitlements` / `Release.entitlements` | `com.apple.security.app-sandbox` | 沙盒（默认开） |
| 同上 | `com.apple.security.device.audio-input` | **麦克风，缺了语音直接失败** |
| 同上 | `com.apple.security.network.client` | 语音识别可能联网 |
| 同上 | `com.apple.security.files.user-selected.read-write` | 用户选定的导出/备份目录 |
| 同上 | `com.apple.security.files.bookmarks.app-scope` | 持久化目录授权 |

`Info.plist` 另需 `NSMicrophoneUsageDescription`、`NSSpeechRecognitionUsageDescription`。

**目录授权（security-scoped bookmark）**——这是必踩坑：

```
用户选目录 → 生成 bookmark → base64 存 settings.backup_dir_bookmark
每次读写前：resolveBookmarkData() → startAccessingSecurityScopedResource()
          → 读/写 → stopAccessingSecurityScopedResource()
重启 App 后必须走这套，否则写入静默失败
```

`settings.backup_dir` 只作为展示用路径，真正授权以 bookmark 为准。

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

## 七、语音输入实现

```
SpeechService（状态机：idle / listening / error）
  └─ start()
       ├─ permission_handler 请求麦克风
       ├─ speech_to_text.initialize()
       ├─ listen(onResult: 回填标题)
       └─ stop() / cancel()
```

| 平台 | 底层 | 前置 |
|---|---|---|
| Android | `SpeechRecognizer`（通常 Google 语音，**联网**） | Manifest 麦克风 + INTERNET |
| macOS | `SFSpeechRecognizer` | entitlements（麦克风 + network.client）+ Info.plist 两项用途说明 |

**降级**：不可用 / 无权限 / 空结果 → 明确中文提示，手动输入永远可用。

**测试**：语音难自动化，只测 `SpeechService` 的状态封装，不测识别质量。

---

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
| **自动备份** | `backup_service` | 每日首启写全量 JSON；macOS 用 bookmark；`zhaoxi-YYYYMMDD.json`，保留 14 份 |

**相关实现落点**

- **视图管理**：`view_order` / `view_hidden` / `view_labels` 存 `settings`，由 `task_list` 读取；锁定 `all` / `done`（见 05 §四）。
- **清单**：内置 `list-work` / `list-life` 固定 id（见 05 §三）；`list_dao` 管理；首页清单筛选叠加在视图查询之上。
- **字体许可**：PDF 用的 SourceHanSerifCN 采用 **SIL OFL-1.1**，需随包附带许可证文本，并在「关于 → 开源许可」中列出。

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

### Android

```bash
flutter build apk --release          # 或 --split-per-abi 减小体积
```
侧载安装（允许"未知来源"）。可自建静态目录放 APK，手机浏览器下载。

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
| 手动测试清单 | 通知到点是否触发（真机）、Android 14 精确闹钟授权流程、语音权限流程、导出文件能打开、macOS 备份目录重启后仍可写、杀进程后数据仍在 |

`flutter analyze` 必须零 warning。

---

## 十四、开发环境

已验证本机具备：Flutter + Dart、Android SDK + adb。

缺失需补：**Xcode**（macOS 桌面构建必需）、**CocoaPods**。
建议在 **M0 期间就顺手跑通一次 macOS 构建**，避免 M4 集中踩坑。
