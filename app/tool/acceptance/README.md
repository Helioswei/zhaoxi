# 验收

App 内部流程用 **integration_test** 驱动（按控件找、真实点击，不看坐标和截图）；
系统侧的事情（数据库、闹钟队列、权限）用 adb 在测试跑完后补断言。

## 为什么不用坐标 / 截图

试过，废了：坐标点击在模拟器上会被吞，截图比对又会因为改样式、改布局而失效。
两者都是「比对长什么样」，而不是「是什么」。现在：

| 要做什么 | 用什么 | 为什么不失效 |
|---|---|---|
| 点按钮、填内容、切视图 | `integration_test`：`find.byTooltip` / `find.text` / `find.byType` | 只认控件身份，改样式/布局不影响 |
| 断言业务结果 | 读数据库（sqlite） | 数据是真相源 |
| 断言系统行为 | `dumpsys alarm` / `dumpsys package` | 系统状态是真相源 |

## 怎么跑

```bash
cd app
./tool/acceptance/run_app_flow.sh      # 新建任务 → 提醒落库 → 系统有闹钟
./tool/acceptance/run_backup_flow.sh   # 立即备份 → 从本机备份恢复
./tool/acceptance/run_next_week.sh     # 回归：「下周」不能算到过去
```

两个脚本都是「跑 integration_test + 在 App 外补断言 + 清理」。

它会：

1. `flutter drive` 跑 `integration_test/task_flow_test.dart`（真实点击，跑完保留 App）
2. 读数据库断言：任务在、`remind_at` 有值
3. `dumpsys alarm` 断言：系统里有本 App 的闹钟
4. 删掉这条验收任务

日志在 `/tmp/zhaoxi-acceptance/`。

## 两个坑（脚本里已经处理）

1. **保存任务会请求通知权限**：没授权时会弹系统权限框，测试会卡住。
   `run_app_flow.sh` 在跑测试的同时循环 `pm grant`，抢在保存之前把权限给上。
   （精确闹钟不会在这里申请了——见 docs/08 的 T-11。）
2. **`flutter test` 跑完会卸载 App**，数据和闹钟都没了。所以用 `flutter drive`
   并加 `--keep-app-running`，跑完 App 还在，才能做系统侧断言。

## 还没自动化的部分

- **「存到文件夹」的导出**：需要先有一次「授权备份文件夹」，而那个授权页是系统的
  目录选择器，integration_test 驱动不了。`backup_flow_test.dart` 里做了判断：
  没授权就 `markTestSkipped`，不会假失败。首次手动授权一次即可：
  设置 → 备份与恢复 → 从文件恢复 → 选择文件夹。
- **完整换机演练**（导出 → `pm clear` → 导入）：中间那步 `pm clear` 会把
  App 的授权一起清掉，导入又要重新走系统选择器，所以暂时只能手动。

## 加新流程

在 `integration_test/` 下加一个 `*_test.dart`，用控件定位、只断言界面；
需要在 App 外面验证的东西（文件、闹钟、权限），加到 `run_app_flow.sh` 的断言段。

写测试时注意：任务在「明天」时不会出现在「今天」视图里，断言前先切视图。

## 文件

| 文件 | 作用 |
|---|---|
| `run_app_flow.sh` | 总入口：跑测试 + 系统侧断言 + 清理 |
| `lib.sh` | adb / 数据库辅助函数（拉库、查值、截图） |
| `db_query.py` | 对拉下来的 sqlite 跑一句查询 |
| `../../integration_test/task_flow_test.dart` | 新建任务的真实点击流程 |
| `../../integration_test/next_week_test.dart` | 「下周」日期回归 |
| `../../integration_test/ui_regressions_test.dart` | 时间选择、长按拖拽的回归 |
| `../../test_driver/integration_test.dart` | `flutter drive` 的驱动入口 |
