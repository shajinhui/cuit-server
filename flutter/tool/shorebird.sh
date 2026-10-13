#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  cat <<'USAGE'
用法（在 flutter/ 下执行）：
  ./tool/shorebird.sh login
  ./tool/shorebird.sh init
  ./tool/shorebird.sh validate
  ./tool/shorebird.sh release android|ios [Shorebird 参数]
  ./tool/shorebird.sh patch android|ios <基础版本，例如 0.1.0+2> [Shorebird 参数]

首次使用先安装 Shorebird CLI，再 login、init。
init 会绑定真实应用并关闭引擎的自动检查，由客户端统一管理后台更新。
release 使用 .flutter-version，patch 使用目标基础版本记录的引擎。
SHOREBIRD_BIN 可指定 Shorebird 可执行文件，其余命令透传给 CLI。
USAGE
}

validate_config() {
  python3 - <<'PY'
from pathlib import Path
import re
import sys
import uuid

path = Path('shorebird.yaml')
if not path.exists():
    sys.exit('尚未绑定 Shorebird 应用，请先执行 ./tool/shorebird.sh login 和 init。')
config = path.read_text()
match = re.search(r'^app_id:\s*[\'\"]?([0-9a-fA-F-]{36})[\'\"]?\s*(?:#.*)?$', config, re.M)
if not match:
    sys.exit('shorebird.yaml 中缺少有效的 app_id，请使用 Shorebird CLI 初始化。')
try:
    app_id = uuid.UUID(match[1])
    if app_id.int == 0:
        raise ValueError()
except ValueError:
    sys.exit('shorebird.yaml 的 app_id 无效，请使用真实应用标识。')
if not re.search(r'^auto_update:\s*false\s*(?:#.*)?$', config, re.M):
    sys.exit('请在 shorebird.yaml 中设置 auto_update: false，避免重复检查和下载。')
if not re.search(r'^\s+-\s*[\'\"]?shorebird\.yaml[\'\"]?\s*(?:#.*)?$', Path('pubspec.yaml').read_text(), re.M):
    sys.exit('pubspec.yaml 缺少 shorebird.yaml 资源，请完成 Shorebird CLI 初始化。')
print('Shorebird 应用配置检查通过。')
PY
}

task_command="${1:-help}"
case "$task_command" in
  help|-h|--help)
    usage
    exit 0
    ;;
  validate)
    validate_config
    exit 0
    ;;
  release|patch)
    if [[ "${2:-}" != android && "${2:-}" != ios ]]; then
      usage >&2
      exit 1
    fi
    if [[ "$task_command" == patch && ! "${3:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
      echo 'patch 必须指定完整基础版本，例如 0.1.0+2。' >&2
      exit 1
    fi
    validate_config
    ;;
  init)
    if [[ -f shorebird.yaml ]]; then
      echo '已有 shorebird.yaml，请沿用应用标识；如需调整绑定，请直接使用 Shorebird CLI。' >&2
      exit 1
    fi
    ;;
esac

if [[ -n "${SHOREBIRD_BIN:-}" ]]; then
  task_shorebird_bin="$SHOREBIRD_BIN"
elif command -v shorebird >/dev/null 2>&1; then
  task_shorebird_bin="$(command -v shorebird)"
elif [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
  task_shorebird_bin="$HOME/.shorebird/bin/shorebird"
else
  echo '请先按 https://docs.shorebird.dev/getting-started/ 安装 Shorebird CLI，或设置 SHOREBIRD_BIN。' >&2
  exit 1
fi

# 与普通 Flutter 构建保持相同的本机工具链，不修改全局 Xcode 设置。
if [[ -z "${ANDROID_HOME:-}" && -d "$HOME/.local/share/cuit-android-sdk" ]]; then
  export ANDROID_HOME="$HOME/.local/share/cuit-android-sdk"
fi
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

case "$task_command" in
  init)
    shift
    "$task_shorebird_bin" init "$@"
    python3 - <<'PY'
from pathlib import Path
import re

path = Path('shorebird.yaml')
config = path.read_text()
if re.search(r'^auto_update:', config, re.M):
    config = re.sub(r'^auto_update:.*$', 'auto_update: false', config, flags=re.M)
else:
    config = config.rstrip() + '\n\n# 客户端统一管理后台检查、下载和状态展示。\nauto_update: false\n'
path.write_text(config)
PY
    validate_config
    ;;
  release)
    task_platform="$2"
    shift 2
    task_flutter_version="$(tr -d '\r\n' < .flutter-version)"
    exec "$task_shorebird_bin" release "$task_platform" --flutter-version="$task_flutter_version" "$@"
    ;;
  patch)
    task_platform="$2"
    task_release_version="$3"
    shift 3
    exec "$task_shorebird_bin" patch "$task_platform" --release-version="$task_release_version" "$@"
    ;;
  *)
    exec "$task_shorebird_bin" "$@"
    ;;
esac
