# 朝夕 — 数据模型

> 版本：v0.5
> 日期：2026-10-12
> 状态：待评审（已吸收评审意见 + 真实使用场景补充）
> 依赖：[04-技术架构](./04-技术架构-TECHNICAL.md)

---

## 一、设计约定

| 约定 | 说明 |
|---|---|
| 主键 | `id`：UUID v4 字符串 |
| 时间 | 全部 **UTC 毫秒整数**；展示转本地时区 |
| **日界** | "今天/明天/本周/本月"在**本地时区**计算后转 UTC 比较；集中在 `domain/day_boundary.dart` |
| 周界 | **周一–周日**（固定，不做设置项） |
| 软删除 | `deleted` 布尔；查询默认过滤 |
| 版本字段 | `updated_at`、`origin_device` |
| 长度计数 | 按**字素簇**（`characters` 包） |

---

## 二、表：`tasks`

| 列名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | TEXT | PK | UUID |
| `title` | TEXT | NOT NULL | 1–200 字素簇 |
| `note` | TEXT | NULL | ≤2000 字素簇 |
| **`list_id`** | TEXT | NOT NULL | 所属清单，外键 → `lists.id` |
| `status` | INTEGER | NOT NULL DEFAULT 0 | 0=待办，1=已完成 |
| `due_at` | INTEGER | NULL | 截止时间（UTC 毫秒）；**NULL = 待定** |
| `due_has_time` | INTEGER | NOT NULL DEFAULT 0 | 0=只到某天；1=精确到分钟 |
| `remind_at` | INTEGER | NULL | 提醒时间；NULL=不提醒 |
| `notif_id` | INTEGER | NULL | 系统通知 ID（自增） |
| `repeat_rule` | TEXT | NULL | JSON，NULL=不重复 |
| `completed_count` | INTEGER | NOT NULL DEFAULT 0 | 重复任务累计完成次数 |
| `is_important` | INTEGER | NOT NULL DEFAULT 0 | P2 |
| `sort_order` | REAL | NOT NULL DEFAULT 0 | 手工排序权重 |
| `completed_at` | INTEGER | NULL | 最后一次完成时间 |
| `created_at` | INTEGER | NOT NULL | |
| `updated_at` | INTEGER | NOT NULL | |
| `deleted` | INTEGER | NOT NULL DEFAULT 0 | |
| `origin_device` | TEXT | NOT NULL | 设备 UUID |

**索引**

```sql
CREATE INDEX idx_tasks_status_due   ON tasks(status, deleted, due_at);
CREATE INDEX idx_tasks_list         ON tasks(list_id, status, deleted);
CREATE INDEX idx_tasks_sort_order   ON tasks(sort_order);
```

**约束**：`due_at IS NULL` 时 `due_has_time` 恒为 0；`(1, NULL)` 为非法组合。应用层保证 + `CHECK (due_at IS NOT NULL OR due_has_time = 0)`。

**`repeat_rule` JSON（P1）**

```json
{ "freq": "daily"|"weekly"|"monthly"|"interval",
  "interval": 1, "byWeekday": [3], "until": null, "count": null }
```

> `byWeekday` 编号约定：**1=周一 … 7=周日**，与“周界固定周一–周日”一致。

### 2.1 字段语义（易错点）

| 场景 | `due_has_time` | `due_at` | `remind_at` |
|---|---|---|---|
| 只选"明天" | 0 | 明天**本地 00:00** 的 UTC 值 | 明天**本地 09:00**（默认，可改；已过则不排） |
| 选"明天 9:00" | 1 | 明天本地 09:00 的 UTC 值 | = `due_at` |
| **不设时间** | 0 | **NULL**（归「待定」） | NULL |

---

## 三、表：`lists`（清单）

| 列名 | 类型 | 约束 | 说明 |
|---|---|---|---|
| `id` | TEXT | PK | UUID |
| `name` | TEXT | NOT NULL | 显示名（工作/生活/…） |
| `color` | TEXT | NULL | 色值 |
| `sort_order` | REAL | NOT NULL DEFAULT 0 | |
| `is_builtin` | INTEGER | NOT NULL DEFAULT 0 | 内置清单不可删 |
| `deleted` | INTEGER | NOT NULL DEFAULT 0 | |
| `updated_at` | INTEGER | NOT NULL | |
| `origin_device` | TEXT | NOT NULL | |

**预置数据**（首启插入）

| id | name | color | is_builtin |
|---|---|---|---|
| `list-work` | 工作 | `#3B6EA5` | 1 |
| `list-life` | 生活 | `#3B7A6E` | 1 |

> **内置清单用固定字符串 id（非 UUID）**，这是有意为之：跨设备合并时“工作/生活”才能对上；自定义清单用 UUID。
> 内置清单 **不可删除**，可改名/改色；自定义清单可删（删除前任选任务归属）。

---

## 四、表：`settings`

| 列名 | 类型 | 约束 |
|---|---|---|
| `key` | TEXT | PK |
| `value` | TEXT | NULL |
| `updated_at` | INTEGER | NOT NULL |

**预置键**

| key | 默认 | 含义 |
|---|---|---|
| `device_id` | 首启生成 UUID | **永不被导入覆盖** |
| `notif_id_counter` | 1 | 通知 ID 计数器 |
| `theme_mode` | `system` | system/light/dark |
| `font_scale` | `normal` | normal/large |
| `default_remind_offset` | `0` | 提前分钟数 |
| `date_only_remind_time` | `09:00` | 日期型默认提醒时刻 |
| `speech_locale` | `zh_CN` | |
| **`default_view`** | `today` | 默认打开的视图（首次进入） |
| **`view_order`** | `["today","tomorrow","week","month","later","undated","all","done"]` | 视图顺序 |
| **`view_hidden`** | `[]` | 被隐藏的视图 id（不含 all/done） |
| **`view_labels`** | `{}` | 重命名覆盖，如 `{"week":"这周"}` |
| **`active_list_filter`** | `all` | 上次选中的清单筛选 |
| **`last_used_list`** | `life` | 新建任务默认清单（筛选为「全部」时用） |
| `nudge_undated_weekly` | `false` | 每周整理"待定"提醒开关 |
| `last_backup_date` | NULL | |
| `backup_dir` | NULL | 展示路径 |
| `backup_dir_bookmark` | NULL | macOS bookmark（base64） |
| `backup_keep` | `14` | |

**视图 id 对照**

| id | 默认名 | 锁定 |
|---|---|---|
| `today` | 今天 | 否 |
| `tomorrow` | 明天 | 否 |
| `week` | 本周 | 否 |
| `month` | 本月 | 否 |
| `later` | 以后 | 否 |
| `undated` | 待定 | 否 |
| `all` | 全部 | **是** |
| `done` | 已完成 | **是** |

---

## 五、视图查询

> 边界值（本地时区计算后转 UTC）：`TODAY_END` / `TOMORROW_END` / `WEEK_START` / `WEEK_END` / `MONTH_START` / `NEXT_MONTH_START`。

| 视图 | 条件（均 `deleted = 0`） | 排序 |
|---|---|---|
| 待定 `undated` | `status=0 AND due_at IS NULL` | `created_at DESC` |
| 今天 `today` | `status=0 AND due_at IS NOT NULL AND due_at < TODAY_END` | `due_at ASC, sort_order ASC` |
| 明天 `tomorrow` | `status=0 AND due_at >= TODAY_END AND due_at < TOMORROW_END` | `due_at ASC, sort_order ASC` |
| 本周 `week` | `status=0 AND due_at >= WEEK_START AND due_at < WEEK_END` | `due_at ASC, sort_order ASC` |
| 本月 `month` | `status=0 AND due_at >= MONTH_START AND due_at < NEXT_MONTH_START` | `due_at ASC, sort_order ASC` |
| 以后 `later` | `status=0 AND due_at >= NEXT_MONTH_START` | `due_at ASC` |
| 全部 `all` | `status=0` | 按 **逾期→今天→明天→本周→本月→以后→待定** 顺序，**每条只进第一个匹配的组**（避免重叠入多组）；**组内按 `sort_order`（手工拖拽顺序）** |
| 已完成 `done` | `status=1` | `completed_at DESC`，LIMIT 500 + 加载更多 |

**清单筛选**：上述任一视图都可叠加 `AND list_id = :list`（或全部清单）。

---

## 六、导出 JSON 结构

```json
{
  "app": "zhaoxi",
  "exportFormatVersion": 1,
  "dbSchemaVersion": 1,
  "exportedAt": 1791500000000,
  "taskCount": 15,
  "lists": [ { "id": "list-work", "name": "工作", "color": "#3B6EA5" } ],
  "tasks": [
    {
      "id": "…", "title": "交材料", "note": null,
      "listId": "list-work", "status": 0,
      "dueAt": 1791600000000, "dueHasTime": true,
      "remindAt": 1791600000000, "repeatRule": null,
      "completedCount": 0, "isImportant": false, "sortOrder": 1024.0,
      "completedAt": null, "createdAt": 1791500000000,
      "updatedAt": 1791500000000, "deleted": false, "originDevice": "…"
    }
  ],
  "settings": { "theme_mode": "system", "date_only_remind_time": "09:00" }
}
```

> **不含 `deviceId`。** 如需诊断用 `_diagnosticDeviceId`（导入一律忽略）。否则两台设备 `origin_device` 会相同，未来同步的平局兜底失效。
>
> **JSON 恒为全量备份**：不含 `kind` / `range` / `filter`（范围导出只存在于 PDF/Markdown，见 02 §2.6）。

**导入规则**

| 场景 | 行为 |
|---|---|
| `exportFormatVersion` > 当前 | 拒绝："备份来自更新版本" |
| `<` 当前 | 走**格式升级路径** |
| 缺字段 | 默认值补齐 |
| `listId` 指向不存在的清单（合并模式） | **自动创建同名清单**（无损） |
| `listId` 指向不存在的清单（覆盖模式） | 判为**校验失败并拒绝导入**（覆盖时 `lists` 从同一文件重建，缺清单只可能是文件损坏） |
| 合并 | 按 `id`，`updated_at` 大者胜 |
| 覆盖 | 清空 `tasks`/`lists` 再写入；**写入前先取消本机全部已排程通知**，写入后按新数据重排 |
| `settings` | 仅"覆盖"可选应用；**`device_id`、`notif_id_counter`、视图配置永不导入** |

---

## 七、Markdown / PDF 导出结构

见 [02 §5.2 月报模板](./02-需求规格-REQUIREMENTS.md)。要点：

- 按**周**分节（周一–周日），标题形如 `10 月第 1 周（10.01–10.04）`。
- 条目 `- [x] 标题（10.02）`，备注缩进 `> `。
- 末尾可选"未完成 / 结转下月"章节。
- `- [ ]` / `- [x]` 兼容 Obsidian / GitHub。

---

## 八、版本与迁移

| 版本 | 范围 | 递增时机 | 兼容策略 |
|---|---|---|---|
| `dbSchemaVersion` | Drift 结构 | 每次改表 | Drift `MigrationStrategy` |
| `exportFormatVersion` | 导出 JSON 格式 | 导出结构变化时 | 逐级升级函数 |

- 迁移**幂等且可测试**（测试里造旧库跑迁移）。
- 破坏性变更前自动导出全量 JSON 保底。
- 两个版本独立：**改数据库结构不影响旧备份可导入性**。

---

## 九、数据生命周期

| 事件 | 处理 |
|---|---|
| 新建 | 插入行，`list_id` = 默认清单（规则见 02 §2.3）；**不分配 `notif_id`** |
| 编辑 | 更新 + `updated_at`；重排通知（**此时才分配 `notif_id`**） |
| 完成（普通） | `status=1`，`completed_at=now`，取消通知 |
| 完成（重复） | `due_at` 跳到 **`now` 之后第一个符合规则的时间点**（逾期多期不逐格补），`completed_count+1`，`completed_at=now`，status 保持 0，重排通知 |
| 撤销完成（普通） | `status=0`；`remind_at` 在未来则重排，已过则不排并提示 |
| 撤销完成（重复） | **按 `repeat_rule` 反向推回上一个周期**恢复 `due_at`，`completed_count-1`；若已跨过该时刻则重排通知 |
| 删除 | `deleted=1`，取消通知 |
| 撤销删除 | `deleted=0`；`remind_at` 在未来则重排，已过则不排并提示 |
| 删除清单 | 由用户在删除前**选择归属清单**（默认"生活"），所选清单的 `list_id` 迁移过去 |
| 清空已删除 | 设置 → 危险，手动触发：物理删除 `deleted=1` 且 >30 天的行；这些行已无通知，不影响通知 |
| 清空数据 | 见 03 §3.6：范围可选（仅 tasks+lists / 含 settings）；**必先二次确认**；**先取消全部通知**；可选"清空前自动导出 JSON"；`device_id`/`notif_id_counter` 始终保留 |
| 导入覆盖 | 清空 `tasks`/`lists` 再写入；**先取消本机全部已排程通知**，写入后按新数据重排；不动 `device_id` / `notif_id_counter` / 视图配置 |
