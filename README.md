# 朝夕

> 一个给自己和家人用的极简待办 App。**Android + macOS，任务数据全在本机。**

打开就写、点一下完成、说句话就能记 —— 别的都不要。

---

## 现在到哪一步了

🚧 **开发中（M4 基本完成）**：MVP（M0–M3）+ M4 的 P1 项已就位。

- ✅ M0：数据层、清单、8 视图、新建/编辑、完成/删除+撤销、浅色主题
- ✅ M1：本地提醒（通知渠道、权限与降级、排程/取消、点通知跳转、默认提前量）
- ~~M2 语音输入~~：**已取消**（依赖系统识别、部分机型不可用）
- ✅ M3：导出/导入（月报 Markdown/PDF、全量 JSON 备份、合并/覆盖导入）
- ✅ M4：深色模式、视图管理、搜索、**重复任务**、**组内拖拽排序**、自动备份、应用图标、大字号、桌面快捷键
- ⏳ 仅剩：macOS 构建（需先装 Xcode）；启动页可选

见 [开发计划](./docs/06-开发计划-ROADMAP.md)。

---

## 文档

从 [docs/index.md](./docs/index.md) 进入，或直接看：

| 文档 | 内容 |
|---|---|
| [01 产品定位](./docs/01-产品定位-PRODUCT.md) | 为什么做、给谁用、不做什么 |
| [02 需求规格](./docs/02-需求规格-REQUIREMENTS.md) | 用户故事、权限总表、视图与清单、验收标准 |
| [03 功能设计](./docs/03-功能设计-FUNCTIONAL.md) | 页面、交互、视觉规范（色值已实测） |
| [04 技术架构](./docs/04-技术架构-TECHNICAL.md) | 技术栈、分层、时区、通知、macOS 沙盒、打包 |
| [05 数据模型](./docs/05-数据模型-DATA-MODEL.md) | 表结构、导出格式、版本与迁移 |
| [06 开发计划](./docs/06-开发计划-ROADMAP.md) | M0–M5 里程碑 + 需求 ID 追溯 |

---

## 关键决策

| 维度 | 决策 |
|---|---|
| 平台 | Android（主）+ macOS |
| 框架 | Flutter |
| 存储 | Drift / SQLite，纯本地 |
| 同步 | 暂时不做（架构已预留） |
| 语音 | **不含**（已取消，App 纯离线） |
| 导出 | PDF / Markdown / JSON，经系统面板落盘；**「月报」预设** = 本月+工作+仅已完成+按周+Markdown |
| 视图 | 待定 / 今天 / 明天 / 本周 / 本月 / 以后 / 全部 / 已完成；默认「今天」；可隐藏/排序/重命名（全部与已完成锁定） |
| 清单 | 工作 / 生活（与时间视图正交） |
| 提醒 | 本地通知 + 精确闹钟授权 + 通知渠道 |
| 重复任务 | 原地推进（非复制新记录） |
| AI | 暂不引入 |
| **MVP** | **全部 P0 = M0 + M1(提醒) + M2 + M3**；先行版 v0.1 = M0 + M1 |

---

## 目录结构

```
zhaoxi/
├── docs/     # 文档（产品 / 需求 / 功能 / 技术 / 数据 / 计划）
└── app/      # Flutter 工程（待创建）
```

---

## 构建（CI）

`.github/workflows/build.yml`：

| 触发 | 做什么 |
|---|---|
| push 到 `main`（改 `app/**`） | `flutter analyze` + `flutter test` + 构建 Android APK（拆分 ABI）与 macOS `.app`，产物在 Actions → Artifacts |
| 手动 Run workflow | 同上 |
| 打 tag（`v1.0.0`） | 自动创建 GitHub Release，并把 APK / macOS 包挂上去 |

> **签名**：Android 用固定的 release keystore（`android/key.properties` → `~/AIWork/.zhaoxi-signing/zhaoxi-release.jks`，已 gitignore）。
> CI 通过 4 个 secrets 注入：`ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。
> ⚠️ **换签名后旧版无法覆盖升级**：先导出 JSON 备份 → 卸载旧版 → 安装新版 → 导入备份。

## 开源协议

本项目采用 **MIT License**，详见 [LICENSE](./LICENSE)。
