#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/sync_calendar.py --check
./tool/flutter-ohos.sh pub get --enforce-lockfile
./tool/flutter-ohos.sh analyze --no-pub
./tool/flutter-ohos.sh test --no-pub
./tool/flutter-ohos.sh build hap --no-pub --no-codesign --debug --target-platform ohos-arm64
