#!/usr/bin/env bash
# 验收脚本公共库：真机/模拟器上的点击、等待、断言。
#
# 设计取舍：
# - 操作用真实点击（adb input tap）+ 键盘输入，模拟用户；测试数据不直接写库；
# - 断言尽量读「真相源」——数据库、dumpsys、文件系统，而不是读界面文字
#   （Flutter 默认不向 uiautomator 暴露语义树，读不到控件文字）；
# - 坐标只对当前设备有效（见 README 的「重新校准」）。
set -uo pipefail

PKG="${PKG:-com.helioswei.zhaoxi}"
ADB="${ADB:-adb}"
OUT="${OUT:-/tmp/zhaoxi-acceptance}"
TAPS="${TAPS:-$(dirname "${BASH_SOURCE[0]}")/taps.conf}"

mkdir -p "$OUT"

FAILED=0
log()  { printf '\033[1m▸ %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$*"; FAILED=$((FAILED+1)); }

need_device() {
  if ! $ADB devices | grep -q "device$"; then
    echo "没有连上设备（adb devices 空）"; exit 1
  fi
}

# tap <名字>：从 taps.conf 里读 x,y
tap() {
  local name="$1" line xy
  line="$(grep -m1 "^${name}=" "$TAPS" 2>/dev/null)" || {
    echo "taps.conf 里没有 ${name}"; exit 1; }
  xy="${line#*=}"
  $ADB shell input tap "${xy%,*}" "${xy#*,}"
}

tap_xy() { $ADB shell input tap "$1" "$2"; }
type_text() { $ADB shell input text "$1"; }
swipe_up() { $ADB shell input swipe 540 1800 540 1100 300; }

shot() { $ADB exec-out screencap -p > "$OUT/$1.png"; echo "  截图：$OUT/$1.png"; }

# 等首帧：闪屏只有奶油底 + 绿块（颜色极少），首页有卡片、文字、色块。
# 用颜色数量区分，比固定 sleep 稳，也比 -W 可靠（-W 在模拟器上会先超时）。
app_in_front() {
  $ADB shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus | grep -q "$PKG"
}

wait_first_frame() {
  local i=0
  while [ "$i" -lt 40 ]; do
    # 先确认前台是本 App（否则可能在桌面，桌面颜色多，光看颜色会误判）
    if app_in_front; then
      $ADB exec-out screencap -p > "$OUT/_frame.png" 2>/dev/null
      if python3 "$(dirname "${BASH_SOURCE[0]}")/is_home.py" "$OUT/_frame.png"; then
        return 0
      fi
    fi
    sleep 1
    i=$((i+1))
  done
  return 1
}

# 慢设备上 Flutter 偶尔会弹「无响应」，点 Wait 让它继续，而不是让脚本卡死。
dismiss_anr() {
  if $ADB shell dumpsys window 2>/dev/null | grep -q "Application Not Responding"; then
    $ADB shell input tap 381 1738
    sleep 2
  fi
}

launch() {
  $ADB shell am force-stop "$PKG"
  $ADB shell am start -n "$PKG/.MainActivity" >/dev/null
  if ! wait_first_frame; then
    echo "40 秒内没等到首帧（模拟器太慢？）"
    return 1
  fi
  dismiss_anr
  sleep 3
}

# wait_for <秒> <命令...>
wait_for() {
  local timeout="$1"; shift
  local waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 2; waited=$((waited+2))
  done
  return 1
}

db_pull() {
  $ADB shell am force-stop "$PKG" >/dev/null 2>&1
  $ADB exec-out run-as "$PKG" cat app_flutter/zhaoxi.db > "$OUT/db.sqlite"
}

# db_value <SQL>：从刚拉下来的库里取一个值
db_value() {
  python3 "$(dirname "${BASH_SOURCE[0]}")/db_query.py" "$OUT/db.sqlite" "$1"
}

db_push() {
  $ADB push "$OUT/db.sqlite" /data/local/tmp/zhaoxi.db >/dev/null
  $ADB shell "run-as $PKG sh -c 'cat /data/local/tmp/zhaoxi.db > app_flutter/zhaoxi.db'"
}

grant_notifications() {
  $ADB shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS 2>/dev/null
}

# 弹层打开时页面顶部会被遮罩压暗；首页是奶油底（亮）。
# 用这个判断弹层状态，比「看某个点是不是白色」稳。
sheet_open() {
  $ADB exec-out screencap -p > "$OUT/_sheet.png" 2>/dev/null
  python3 "$(dirname "${BASH_SOURCE[0]}")/is_scrim.py" "$OUT/_sheet.png"
}

# 断言失败就中止：绝不在错误页面上继续点，否则会点到别的功能上去。
fail() {
  bad "$*"
  shot "FAILED"
  summary
  exit 1
}

# 点开「新建任务」弹层：模拟器偶尔吞掉点击，点一次验一次，最多 5 次。
open_new_task_sheet() {
  local i
  for i in 1 2 3 4 5; do
    tap fab
    sleep 2
    if sheet_open; then return 0; fi
  done
  return 1
}

# 等某个条件成立（用函数名），超时就失败
expect() {
  local what="$1" check="$2" i=0
  while [ "$i" -lt 10 ]; do
    if "$check"; then return 0; fi
    sleep 1
    i=$((i+1))
  done
  fail "没等到：$what"
}


# 键盘是否弹出（系统信号，比看截图可靠）
keyboard_shown() {
  $ADB shell dumpsys input_method 2>/dev/null | grep -q "mInputShown=true"
}

# 点输入框直到键盘弹出来（模拟器会吞点击）
focus_title_field() {
  local i
  for i in 1 2 3 4; do
    tap sheet_title
    sleep 1.2
    if keyboard_shown; then return 0; fi
  done
  return 1
}

# 等键盘收起来（返回键之后）
keyboard_hidden() {
  local i=0
  while [ $i -lt 10 ]; do
    keyboard_shown || return 0
    sleep 1
    i=$((i+1))
  done
  return 1
}

summary() {
  echo
  if [ "$FAILED" -eq 0 ]; then
    echo "✅ 全部通过"
  else
    echo "❌ ${FAILED} 项失败（截图在 ${OUT}）"
    exit 1
  fi
}
