"""Refuse to build with a different Flutter OH release than the project pins."""

import json
from pathlib import Path
import sys


def main() -> None:
    actual = json.loads(Path(sys.argv[1]).read_text())
    expected = Path(sys.argv[2]).read_text().strip()
    version = actual.get('frameworkVersion', actual.get('flutterVersion', ''))
    # A source checkout may use a shortened Flutter version but retains the
    # release tag. Binary SDKs report the complete release version directly.
    matches = version == expected
    sdk_root = Path(actual.get('flutterRoot', '.'))
    if not matches and sdk_root.is_dir():
        import subprocess

        tag = subprocess.run(
            ['git', '-C', str(sdk_root), 'describe', '--tags', '--exact-match', 'HEAD'],
            text=True, capture_output=True, check=False,
        )
        matches = tag.returncode == 0 and tag.stdout.strip() == expected
    if not matches:
        sys.exit(
            f'鸿蒙 SDK 版本不匹配：需要 {expected}，当前为 {version}。\n'
            '请切换固定版本的 CPF-Flutter SDK，再用 FLUTTER_OHOS_BIN 指定。'
        )


if __name__ == '__main__':
    main()
