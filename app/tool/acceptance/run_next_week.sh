#!/usr/bin/env bash
# 回归：「下周」不能算到过去（周五建任务不该一建就逾期）。
set -uo pipefail
source "$(dirname "$0")/lib.sh"

need_device
LOG="$OUT/next-week.log"

log "跑「下周」回归测试"
flutter drive \
  --driver test_driver/integration_test.dart \
  --target integration_test/next_week_test.dart \
  --keep-app-running \
  -d "$($ADB devices | awk '/device$/ {print $1; exit}')" >"$LOG" 2>&1 &
TEST_PID=$!

while kill -0 "$TEST_PID" 2>/dev/null; do
  $ADB shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
  sleep 0.3
done
wait "$TEST_PID"
TEST_RC=$?

if [ "$TEST_RC" -ne 0 ]; then
  tail -30 "$LOG"
  fail "下周回归失败（日志：${LOG}）"
fi
ok "界面断言通过"

log "断言：库里的 due_at 是下周一，不是过去"
db_pull
DUE="$(db_value "SELECT due_at FROM tasks WHERE title='acceptance-nextweek'")"
[ -n "$DUE" ] || fail "库里没有这条任务"
python3 - "$DUE" <<'PY'
import datetime, sys
ts = int(sys.argv[1]) / 1000
d = datetime.datetime.fromtimestamp(ts).date()
today = datetime.date.today()
monday = today - datetime.timedelta(days=today.weekday())
next_monday = monday + datetime.timedelta(days=7)
assert d == next_monday, f"due_at={d}，期望 {next_monday}"
assert d >= today, f"due_at={d} 落在过去"
print(f"  due_at = {d}（下周一）✓")
PY
[ "$?" -eq 0 ] || fail "due_at 不是下周一"

log "清理"
db_pull
python3 - "$OUT/db.sqlite" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("DELETE FROM tasks WHERE title = 'acceptance-nextweek'")
db.commit()
PY
db_push
$ADB shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1
summary
