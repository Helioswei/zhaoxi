#!/usr/bin/env bash
# 打一个「确定能装能用」的 release 包，并把产物验一遍。
#
# 2026-10-27 那次给出去的包是坏的，两个原因都在这条命令里堵住了：
#   1) 删了 GeneratedPluginRegistrant.java 之后用 --no-pub 构建 →
#      插件没重新生成，APK 里一个插件都没注册，启动就崩在数据库初始化。
#      对策：永远先 pub get，且构建**不带** --no-pub。
#   2) release 的资源合并用了旧缓存 → 少了 ic_notification →
#      通知初始化抛异常。对策：构建完检查 APK 里真的有这个资源。
#
# 用法：
#   tool/build_release.sh            # 构建 + 静态校验
#   tool/build_release.sh --smoke    # 再装到连接的设备上，确认能进首页
set -uo pipefail
cd "$(dirname "$0")/.."

# 输出同时写日志，另开一个窗口就能看进度：
#   tail -f /tmp/zhaoxi-build.log
LOG=/tmp/zhaoxi-build.log
exec > >(tee "$LOG") 2>&1

SMOKE=0
[ "${1:-}" = "--smoke" ] && SMOKE=1

log() { printf '\033[1m▸ %s\033[0m\n' "$*"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$*"; exit 1; }

APK_DIR=build/app/outputs/flutter-apk
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
AAPT2="$(ls -d "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
[ -x "$AAPT2" ] || die "找不到 aapt2（Android SDK build-tools）"

log "进度日志：tail -f ${LOG}"

log "flutter pub get"
flutter pub get >/dev/null || die "pub get 失败"

log "构建 release（split-per-abi）"
flutter build apk --release --split-per-abi || die "构建失败"

log "校验产物"
for apk in "$APK_DIR"/app-*-release.apk; do
  [ -f "$apk" ] || continue
  name="$(basename "$apk")"
  # 先把输出收下来再 grep：`aapt2 | grep -q` 会因为 grep 提前退出触发
  # SIGPIPE，配合 pipefail 会把「匹配成功」误判成失败。
  resources="$("$AAPT2" dump resources "$apk" 2>/dev/null)"
  if ! grep -q "drawable/ic_notification" <<<"$resources"; then
    die "$name 缺少 ic_notification 资源（多半是 release 资源裁剪把它删了，检查 res/raw/keep.xml 和 manifest 的 meta-data）"
  fi
  vermeta="$("$AAPT2" dump badging "$apk" 2>/dev/null | head -1)"
  printf "  ✓ %-32s %s\n" "$name" "$(echo "$vermeta" | grep -o "versionCode='[0-9]*' versionName='[^']*'")"
done

log "离线守卫（不能有网络权限）"
tool/check_offline.sh || die "离线检查没通过"

if [ "$SMOKE" = "1" ]; then
  adb devices | grep -q "device$" || die "没有连接的设备，去掉 --smoke 或接一台"
  log "装机冒烟：装 → 启动 → 查有没有未捕获异常"
  adb uninstall com.helioswei.zhaoxi >/dev/null 2>&1
  adb install -r "$APK_DIR/app-arm64-v8a-release.apk" >/dev/null || die "安装失败"
  adb logcat -c
  adb shell am start -n com.helioswei.zhaoxi/.MainActivity >/dev/null
  sleep 8
  errs="$(adb logcat -d 2>/dev/null | grep -c "Unhandled Exception")"
  focus="$(adb shell dumpsys window | grep -m1 mCurrentFocus)"
  if [ "$errs" != "0" ]; then
    adb logcat -d 2>/dev/null | grep -A3 "Unhandled Exception" | head -8
    die "启动时有未捕获异常，包不可用"
  fi
  echo "$focus" | grep -q "com.helioswei.zhaoxi" || die "App 没在前台：$focus"
  printf "  ✓ 启动正常，没有未捕获异常\n"
fi

echo
log "产物"
for apk in "$APK_DIR"/app-*-release.apk; do
  printf "  %-34s %s  %s\n" "$(basename "$apk")" \
    "$(shasum -a 1 "$apk" | awk '{print $1}')" "$(du -h "$apk" | cut -f1)"
done

IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [ -n "$IP" ]; then
  echo
  echo "手机下载：http://${IP}:8899/app-arm64-v8a-release.apk"
fi
