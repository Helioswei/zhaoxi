---
name: 朝夕
description: 装在自己口袋里的极简待办——松弛、贴手、温而不腻
colors:
  warm-bg: "#FBF8F3"
  warm-card: "#FFFFFF"
  warm-primary: "#3F8F7B"
  warm-accent: "#E9934E"
  warm-danger: "#C4553F"
  warm-ink: "#33302E"
  warm-ink-muted: "#8C8880"
  warm-chip-selected: "#E9F4EF"
  warm-divider: "#F0EAE1"
  warm-bg-dark: "#17151A"
  warm-card-dark: "#221F26"
  warm-primary-dark: "#74C7AF"
  warm-accent-dark: "#F0B478"
  warm-danger-dark: "#FF8A78"
  warm-ink-dark: "#F2ECE6"
  warm-ink-muted-dark: "#A79E96"
  warm-chip-selected-dark: "#2A2B33"
  warm-divider-dark: "#2E2B33"
  list-work: "#3B6EA5"
  list-life: "#3B7A6E"
typography:
  title:
    fontFamily: "系统默认（温润/清爽），ZhaoxiSerif + Noto Serif CJK 回退（纸感）"
    fontSize: "22sp"
    fontWeight: 700
  label:
    fontFamily: "同上"
    fontSize: "14sp"
    fontWeight: 500
rounded:
  card-fresh: "16px"
  card-warm: "22px"
  card-paper: "12px"
  sheet-fresh: "20px"
  sheet-warm: "28px"
  sheet-paper: "16px"
  snackbar: "12px"
spacing:
  xs: "4px"
  sm: "6px"
  md: "10px"
  lg: "14px"
  xl: "20px"
components:
  task-card:
    backgroundColor: "{colors.warm-card}"
    textColor: "{colors.warm-ink}"
    rounded: "{rounded.card-warm}"
    padding: "10px 14px 10px 6px"
  chip-filter:
    backgroundColor: "transparent"
    textColor: "{colors.warm-ink-muted}"
    rounded: "full"
    padding: "0 16px"
  chip-filter-selected:
    backgroundColor: "{colors.warm-chip-selected}"
    textColor: "{colors.warm-primary}"
    rounded: "full"
    padding: "0 16px"
  sheet:
    backgroundColor: "{colors.warm-card}"
    rounded: "{rounded.sheet-warm}"
---

# Design System: 朝夕

## Overview

**Creative North Star: "朝夕之间的口袋日常"**

朝夕的设计不为展示，是为「掏出来 5 秒搞定」。奶油色的纸面托着一份很轻的清单，暖橘只在「今天」出现，逾期给一条陶红，其他时候颜色闭嘴。它像身边一件常用的小物：好按、好认、不用学，家人第一次打开就知道下一步该点哪。

三套风格（清爽 / 温润 / 纸感）共用同一套骨架与组件，只换令牌：底色、圆角、点缀、字体。默认且最能代表朝夕气质的是**温润**。所有判断先对齐温润，再验证另两套不破。

**Key Characteristics:**

- 颜色即状态，绝不为装饰上色
- 平面优先，靠圆角与底色分层，阴影只在温润浅色主题上极轻出现
- 圆角是风格的身份证（清爽 16 / 温润 22 / 纸感 12）
- 中文一等公民，字号随系统缩放（大字号 ×1.2）
- 一切误操作可撤销，反馈用浮起 Snackbar

## Colors

调色是"奶油纸 + 一点茶青绿 + 偶尔的暖橘和陶红"。前台色彩永远稀少，大面积是纸与墨。

> 以下 frontmatter 值为**温润（默认）**的令牌；三风格完整对照表见本节末尾。

### Primary

- **茶青绿**（#3F8F7B / 暗 #74C7AF）：完成圆点、选中态文字、列表清单色点回退色。唯一承担"可以/已办"语义的颜色。

### Secondary

- **暖橘**（#E9934E / 暗 #F0B478）：只标记"今天 / 进行中"。它是日历感的存在，不许当按钮色。

### Tertiary

- **陶红**（#C4553F / 暗 #FF8A78）：逾期分组与删除滑动底色。出现即有事要处理。

### Neutral

- **奶油纸**（#FBF8F3 / 暗 #17151A）：全局底色，杯子里的那层温柔。
- **瓷白卡片**（#FFFFFF / 暗 #221F26）：任务卡片、底部弹层、对话框的Surface。
- **墨**（#33302E / 暗 #F2ECE6）：正文与标题，偏暖的黑。
- **灰墨**（#8C8880 / 暗 #A79E96）：次级文字、提示、未选中筛选 chip。
- **前置浅青**（#E9F4EF / 暗 #2A2B33）：选中 chip 的底色，Primary 的 8% 语气版。
- **纸纹分隔**（#F0EAE1 / 暗 #2E2B33）：1px 分隔线，比卡色略暖。
- **钢青蓝**（#3B6EA5，固定）：内置清单「工作」的色点，不随风格变。
- **苍青绿**（#3B7A6E，固定）：内置清单「生活」的色点，不随风格变。

### Named Rules

**The 颜色即状态 Rule.** 茶青绿=已办，暖橘=今天/进行中，陶红=逾期/删除。这三条语义映射在所有风格、明暗、页面中恒定；任何新 UI 不得把这三个色挪作装饰。

**The 少色 Rule.** 任一屏内彩色占比不超过 5%：色点、勾选圆点、日期标签、chip 选中态。大面积永远是奶油纸/瓷白。

### 三风格对照

| 令牌 | 清爽（浅） | 温润（浅，默认） | 纸感（浅） | 温润（暗） |
|---|---|---|---|---|
| 底色 | #F7F8FA | #FBF8F3 | #F5F0E8 | #17151A |
| 卡片 | #FFFFFF | #FFFFFF | #FDFAF4 | #221F26 |
| 主色 | #3B7A6E | #3F8F7B | #9A6F16 | #74C7AF |
| 点缀/危险 | #3B7A6E / #B3261E | #E9934E / #C4553F | #B8860B / #C23B22 | #F0B478 / #FF8A78 |
| 文字主/次 | #1A1A1A / #667085 | #33302E / #8C8880 | #3C3530 / #8B7E72 | #F2ECE6 / #A79E96 |
| chip 选中 | #E6F1EC | #E9F4EF | #EDE3D2 | #2A2B33 |
| 卡片圆角 | 16 | **22** | 12 | 22 |
| 弹层圆角 | 20 | **28** | 16 | 28 |
| 卡片阴影 | 0 | 1.5（仅浅色） | 0 | 0 |
| 字体 | 系统默认 | 系统默认 | **ZhaoxiSerif 衬线** | 系统默认 |

（清爽/纸感的暗色令牌见 `app/lib/ui/theme/app_style.dart`，规则同温润暗色思路。）

## Typography

**Body Font:** 平台系统默认（Android 系统黑体优先）；纸感风格切换为 **ZhaoxiSerif**（思源宋体子集，回退链 Noto Serif CJK SC → STSong → serif）

**Character:** 不做字体炫技——界面用系统字保证"像原生一样快"；衬线只在纸感风格里整身启用，制造旧时光的慢。字号随系统设置缩放，应用内另有「大字号」= 全局 ×1.2。

### Hierarchy

- **Title**（w700，22sp）：顶栏页标题。每屏最多一个。
- **Body**（系统默认字重与字号，未手工覆写）：任务标题、设置项、日期。
- **Label**（500，14sp）：BottomChip 筛选标签；选中态 14sp / 600 茶青绿。

### Named Rules

**The 系统字优先 Rule.** 正文一律跟系统字号（sp，随无障碍缩放），不许在任何页面为对齐好看而写死 px；纸感整身衬线，绝不允许"衬线混排无衬线"。

## Layout

单列纵向列表是唯一主角：筛选 chips 在上，任务卡卡片沿纸面往下排，FAB（或列表底部）收"新建"。列表 item 左右 12、上下 4 间距；卡片内 6/10/14/10 的不对称内衬托住圆形勾选钮。分组以标题行 + 卡组形成段落，不做全页留白仪式。macOS 桌面端共用此布局，加上 ⌘N 新建、/ 搜索、Esc 取消等键盘路径——同一套视觉，多一条输入通道。

## Elevation & Depth

**平面优先，tonal 分层。** 深度靠"奶油纸 vs 瓷白卡 + 1px 纸纹分隔线"表达，默认无阴影。唯一例外：温润浅色主题卡片 elevation 1.5（rgba 黑 ~10%，极轻），让奶油底上的卡片有一点点"轻轻放在桌上"的托感。暗色主题全部坦平，靠卡色 #221F26 在 #17151A 上略微抬头。

### Named Rules

**The 平面优先 Rule.** 阴影不是常规武器。新组件默认 0 阴影；想要层次，先用底色与圆角，实在不出才申请一枚 ≤10% 黑的轻投影。

## Shapes

圆角策略自带风格签名：卡片 22px（温润）/ 16px（清爽）/ 12px（纸感）；底部弹层顶部 28/20/16，对话框比弹层小 4；筛选 chip 与完成圆点一律 stadium 全圆；Snackbar 12px 浮起，不贴边。按钮与输入框继承卡片圆角家族；输入框去边框（InputBorder.none），靠底色与提示字站住。

### Named Rules

**The 圆角即风格 Rule.** 三个风格之间的第一视觉差异是圆角半径，任何组件必须读 `AppTokens.cardRadius/sheetRadius`，不许写死。

## Components

整体触感：**温厚体贴**——大目标、轻投影、清晰反馈，按下去有一点被托住的感觉。

### 任务卡（TaskTile）
- **形态**：Card 载体 + 圆角卡片（读令牌），内衬 6/10/14/10；左圆形完成钮，中标题+备注，右清单色点/日期标签。
- **色**：卡面瓷白，正文墨色；完成态标题灰墨划除。
- **状态**：点行进编辑弹层；右滑出陶红删除底（含 20px 右距与删除 icon）；完成/删除一律 Snackbar 可撤销。

### 筛选 Chips
- **未选中**：透明底、灰墨字 14sp（#8C8880），stadium 全圆、无边框（side: none）。
- **选中**：浅青底（#E9F4EF），茶青绿 14sp/600 文字。

### FAB
- **唯一主操作**："新建任务"。单屏至多一枚；Material 默认容器色（schema seed 主色），不另行着色。

### 底部弹层（编辑 / 导出面板）
- **形态**：顶部圆角 28（温润）、瓷白卡面、无边无影 surface（surfaceTintColor: transparent）。
- **行为**：时间选择用快捷大按钮（能点就别打字），日期选择器强制 zh_CN。

### Snackbar（撤销反馈）
- **反色浮起**：墨底（#33302E）瓷白字，12px 圆角，floating 不贴边；永远携带"撤销"动作。

### 输入
- **无边框**：InputBorder.none，hint 灰墨；错误态走 Material 默认 error 色（陶红）。

## Do's and Don'ts

### Do:
- **Do** 所有组件颜色/圆角一律走 `context.tokens` / `context.colors`，新颜色先问"它代表什么状态"。
- **Do** 语义色恒定映射：今天=暖橘、进行中=暖橘、逾期=陶红、完成=茶青绿、删除底=陶红。
- **Do** 保持 ≥48dp 触控目标、目标间 ≥8dp 间距（列表 item 现状为 4 上下 + 卡片自身高度，已达）。
- **Do** 深浅两套都逐屏过一遍（`adb shell cmd uimode night yes` + 截图），纸感另查衬线回退。
- **Do** 撤销场景统一走 `showUndoSnack`，文案短句 + "已完成 ✓"/"已删除" 式直述。

### Don't:
- **Don't** 在 widget 代码里写死十六进制色或固定圆角——那是风格令牌的领地。
- **Don't** 用暖橘做按钮/填充主色（它是状态色）；主按钮走 Material seed 主色。
- **Don't** 给平面卡片加多层阴影或大投影，违者先过「平面优先 Rule」。
- **Don't** 引入 Cupertino 控件或 iOS 式底部导航；朝夕是 Material 3 骨架，品牌只在令牌里表达。
- **Don't** 让颜色承担排序/层级——灰墨正文与次级文字之外，不许新增"重要程度红蓝标"之类概念（违背「能少则少」）。
