#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# 仅在当前进程使用本项目准备的 SDK，不改用户的 shell 配置。
if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/.local/share/cuit-android-sdk" ]]; then
  export ANDROID_HOME="$HOME/.local/share/cuit-android-sdk"
fi
# hooks_runner 会过滤 DEVELOPER_DIR；局部包装 xcrun，避免修改全局 xcode-select。
if [[ "$(uname -s)" == Darwin && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
  mkdir -p .dart_tool/local_toolchain
  cat > .dart_tool/local_toolchain/xcrun <<WRAPPER
#!/bin/sh
exec env DEVELOPER_DIR="$DEVELOPER_DIR" /usr/bin/xcrun "\$@"
WRAPPER
  chmod +x .dart_tool/local_toolchain/xcrun
  export PATH="$PWD/.dart_tool/local_toolchain:$PATH"
fi
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  exec "$FLUTTER_BIN" "$@"
elif command -v flutter >/dev/null 2>&1; then
  exec flutter "$@"
elif [[ -x "$HOME/.local/share/cuit-flutter-sdk/bin/flutter" ]]; then
  exec "$HOME/.local/share/cuit-flutter-sdk/bin/flutter" "$@"
else
  echo '请先安装 Flutter，或通过 FLUTTER_BIN 指定 flutter 可执行文件。' >&2
  exit 1
fi
