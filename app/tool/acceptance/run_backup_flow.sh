#!/usr/bin/env bash
# 跑备份页的验收（立即备份 / 恢复 / 存到文件夹），并在 App 外面补断言。
#
# 注意：「存到文件夹」需要先手动授权过一次文件夹（系统目录选择器测试驱动不了），
# 没授权时测试会自己跳过那一步（markTestSkipped）。
set -uo pipefail
source "$(dirname "$0")/lib.sh"

need_device
TEST_FILE="${1:-integration_test/backup_flow_test.dart}"
LOG="$OUT/backup.log"

log "跑 integration_test（备份页）"
flutter drive \
  --driver test_driver/integration_test.dart \
  --target "$TEST_FILE" \
  --keep-app-running \
  -d "$($ADB devices | awk '/device$/ {print $1; exit}')" >"$LOG" 2>&1 &
TEST_PID=$!

while kill -0 "$TEST_PID" 2>/dev/null; do
  $ADB shell pm grant "$PKG" android.permission.POST_NOTIFICATIONS >/dev/null 2>&1
  $ADB shell appops set "$PKG" SCHEDULE_EXACT_ALARM allow >/dev/null 2>&1
  sleep 0.3
done
wait "$TEST_PID"
TEST_RC=$?

if [ "$TEST_RC" -ne 0 ]; then
  tail -30 "$LOG"
  fail "integration_test 失败（完整日志：${LOG}）"
fi
ok "App 内部流程通过"

log "断言：自动备份目录里有备份文件"
COUNT=$($ADB shell "run-as $PKG ls app_flutter/backups 2>/dev/null" | grep -c '\.json$' || true)
[ "${COUNT:-0}" -ge 1 ] && ok "本机备份 $COUNT 份" || fail "备份目录是空的"

log "断言：数据库还能正常打开、任务数不为负"
db_pull
TASKS="$(db_value "SELECT count(*) FROM tasks")"
[ "${TASKS:-x}" -ge 0 ] 2>/dev/null && ok "库里还有 $TASKS 条任务" || fail "数据库读不出来"

$ADB shell am start -n "$PKG/.MainActivity" >/dev/null 2>&1
summary
