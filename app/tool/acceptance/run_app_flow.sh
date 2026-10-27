#!/usr/bin/env bash
# 跑 App 内部流程的验收（integration_test），并在外层补系统侧断言。
#
# 为什么要这个包装：
# - `flutter test integration_test` 会把 App 重新装上，运行时权限是「未授予」；
#   而「保存任务」会请求通知权限 → 系统弹窗 → 测试卡住。
#   所以这里一边跑测试，一边循环 `pm grant`，抢在保存之前把权限给上。
# - 测试只能断言界面；「remind_at 有没有落库」「系统闹钟有没有排上」要读数据库
#   和 dumpsys，这两项放在测试之后做。
set -uo pipefail
source "$(dirname "$0")/lib.sh"

need_device
TEST_FILE="${1:-integration_test/task_flow_test.dart}"
LOG="$OUT/integration.log"

log "跑 integration_test（flutter drive，跑完保留 App）"
flutter drive \
  --driver test_driver/integration_test.dart \
  --target "$TEST_FILE" \
  --keep-app-running \
  -d "$($ADB devices | awk '/device$/ {print $1; exit}')" >"$LOG" 2>&1 &
TEST_PID=$!

# 一边等测试，一边把通知权限塞进去（装包后立刻生效）
while kill -0 "$TEST_PID" 2>/dev/null; do
  $ADB shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
  # 精确闹钟：不设 allow 的话，保存任务会弹系统「闹钟和提醒」页，测试直接卡住
  $ADB shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow >/dev/null 2>&1
  sleep 0.3
done
wait "$TEST_PID"
TEST_RC=$?

if [ "$TEST_RC" -ne 0 ]; then
  tail -30 "$LOG"
  fail "integration_test 失败（完整日志：$LOG）"
fi
ok "App 内部流程通过"

log "断言：任务与提醒已落库（系统侧）"
db_pull
TITLE="$(db_value "SELECT title FROM tasks WHERE title='acceptance-notify'")"
REMIND="$(db_value "SELECT remind_at FROM tasks WHERE title='acceptance-notify'")"
[ "$TITLE" = "acceptance-notify" ] && ok "任务在库里" || fail "库里没有这条任务"
if [ -n "$REMIND" ]; then
  ok "remind_at = $(date -r $((REMIND / 1000)) '+%m-%d %H:%M')"
else
  fail "remind_at 为空"
fi

log "断言：系统闹钟队列里有本 App"
$ADB shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1
sleep 5
$ADB shell dumpsys alarm | grep -q "$PKG" \
  && ok "dumpsys alarm 有待触发的闹钟" \
  || fail "系统里没有本 App 的闹钟"

log "清理这条验收任务"
db_pull
python3 - "$OUT/db.sqlite" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("DELETE FROM tasks WHERE title = 'acceptance-notify'")
db.commit()
PY
db_push
$ADB shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1

summary
