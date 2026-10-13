#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# OHOS 必须使用 CPF-Flutter 的 Flutter fork；官方 Flutter 不认识 ohos 目标。
if [[ -n "${FLUTTER_OHOS_BIN:-}" ]]; then
  task_ohos_flutter="$FLUTTER_OHOS_BIN"
elif [[ -x "$HOME/.local/share/cuit-flutter-ohos-sdk-3.44.9/bin/flutter" ]]; then
  task_ohos_flutter="$HOME/.local/share/cuit-flutter-ohos-sdk-3.44.9/bin/flutter"
elif [[ -x "$HOME/.local/share/cuit-flutter-ohos-sdk/bin/flutter" ]]; then
  task_ohos_flutter="$HOME/.local/share/cuit-flutter-ohos-sdk/bin/flutter"
else
cat >&2 <<'MSG'
未找到 Flutter OHOS 工具链。
请安装与 flutter/.flutter-ohos-version 匹配的 CPF-Flutter SDK，或设置 FLUTTER_OHOS_BIN。
参考： https://gitcode.com/CPF-Flutter/flutter_flutter
MSG
exit 1
fi
# 避免旧版 OH SDK 或官方 Flutter 使用同一锁文件却得到不同依赖结果。
task_ohos_version=$(mktemp)
trap 'rm -f "$task_ohos_version"' EXIT
"$task_ohos_flutter" --version --machine > "$task_ohos_version"
python3 tool/check_ohos_sdk.py "$task_ohos_version" .flutter-ohos-version
rm -f "$task_ohos_version"
trap - EXIT
# OH 与官方 Flutter 固定的 test_api、meta 等不同，分别保留锁文件。
# 只在当前命令期间使用 OH 锁；退出（含失败）时恢复 Android/iOS 锁。
task_ohos_lock_backup=$(mktemp)
task_ohos_had_lock=0
if [[ -f pubspec.lock ]]; then
  cp pubspec.lock "$task_ohos_lock_backup"
  task_ohos_had_lock=1
fi
if [[ -f pubspec.ohos.lock ]]; then
  cp pubspec.ohos.lock pubspec.lock
fi
task_ohos_status=1
restore_lock() {
  if [[ "$task_ohos_status" -eq 0 && -f pubspec.lock ]]; then
    if [[ -f pubspec.ohos.lock ]] || ! cmp -s "$task_ohos_lock_backup" pubspec.lock; then
      cp pubspec.lock pubspec.ohos.lock
    fi
  fi
  if [[ "$task_ohos_had_lock" -eq 1 ]]; then
    cp "$task_ohos_lock_backup" pubspec.lock
  else
    rm -f pubspec.lock
  fi
  rm -f "$task_ohos_lock_backup"
}
trap restore_lock EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if "$task_ohos_flutter" "$@"; then
  task_ohos_status=0
else
  task_ohos_status=$?
fi
exit "$task_ohos_status"
