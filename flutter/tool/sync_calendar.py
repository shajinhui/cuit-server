#!/usr/bin/env python3
"""校历以仓库 shared 中的文件为准，--check 用于构建前检查。"""
import argparse
from pathlib import Path
import shutil

parser = argparse.ArgumentParser()
parser.add_argument('--check', action='store_true')
args = parser.parse_args()
project = Path(__file__).resolve().parent.parent
source = project.parent / 'shared/academiccalendar/calendars.json'
target = project / 'assets/data/calendars.json'
if args.check:
    if not target.exists() or source.read_bytes() != target.read_bytes():
        raise SystemExit('校历资源不同步，请运行 python3 tool/sync_calendar.py')
    print('校历资源一致。')
else:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)
    print('已同步公开校历。')
