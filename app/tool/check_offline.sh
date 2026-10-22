#!/usr/bin/env bash
# 离线守卫：release 产物不允许申请任何网络权限。
#
# 背景：朝夕承诺「纯本地、不联网」。这个承诺不能只写在文档里，
# 得让机器在每次构建时替我们盯着——谁哪天顺手加了个联网的依赖或权限，CI 直接红。
#
# 用法（在 app/ 目录下）：
#   tool/check_offline.sh                # 有 APK 就查 APK，没有就只查 entitlements
#   REQUIRE_APK=1 tool/check_offline.sh  # CI 的 android job 用：必须查到 APK
set -uo pipefail

fail=0
apk_dir="build/app/outputs/flutter-apk"

if [ "${REQUIRE_APK:-0}" = "1" ] && ! ls "$apk_dir"/*release*.apk >/dev/null 2>&1; then
  echo "::error::没找到 release APK，先跑 flutter build apk --release --split-per-abi"
  exit 1
fi

# aapt2 在 Android SDK 里；本地和 CI 的路径不一样，挨个找。
aapt2=""
for root in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
  [ -n "$root" ] || continue
  candidate="$(ls -d "$root"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1)"
  if [ -n "${candidate:-}" ] && [ -x "$candidate" ]; then
    aapt2="$candidate"
    break
  fi
done

for apk in "$apk_dir"/*release*.apk; do
  [ -f "$apk" ] || continue
  echo "── $apk"
  if [ -n "$aapt2" ]; then
    perms="$("$aapt2" dump permissions "$apk" 2>/dev/null)"
  else
    # 退路：二进制 AndroidManifest 里的字符串池
    perms="$(unzip -p "$apk" AndroidManifest.xml 2>/dev/null | strings -el 2>/dev/null | grep -i permission || true)"
  fi
  echo "$perms" | sed 's/^/   /'
  if echo "$perms" | grep -Eq 'android\.permission\.(INTERNET|ACCESS_NETWORK_STATE|ACCESS_WIFI_STATE)'; then
    echo "::error::$(basename "$apk") 申请了网络权限，违反「纯离线」承诺"
    fail=1
  fi
done

# macOS：Release 的 entitlements 里不能出现任何网络能力
if [ -f macos/Runner/Release.entitlements ]; then
  if grep -q "com.apple.security.network" macos/Runner/Release.entitlements; then
    echo "::error::macOS Release.entitlements 含有网络能力，违反「纯离线」承诺"
    fail=1
  fi
  echo "── macOS Release.entitlements：无网络能力"
fi

if [ "$fail" -eq 0 ]; then
  echo "✅ 离线检查通过：release 产物没有任何网络权限"
fi
exit "$fail"
