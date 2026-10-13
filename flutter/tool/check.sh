#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 tool/sync_calendar.py --check
python3 tool/test_shorebird.py
./tool/flutter.sh pub get
./tool/flutter.sh analyze
./tool/flutter.sh test
