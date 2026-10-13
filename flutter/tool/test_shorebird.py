"""在临时项目中验证发布脚本，不登录账号、不构建或上传真实补丁。"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class ShorebirdScriptTest(unittest.TestCase):
    app_id = "12345678-1234-4234-8234-123456789abc"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "tool").mkdir()
        self.script = self.root / "tool/shorebird.sh"
        shutil.copy(Path(__file__).with_name("shorebird.sh"), self.script)
        (self.root / ".flutter-version").write_text("3.47.5\n")
        (self.root / "pubspec.yaml").write_text(
            "name: update_test\nversion: 0.1.0+2\nflutter:\n  assets: []\n"
        )
        self.cli = self.root / "fake-shorebird"
        self.cli.write_text(
            f"#!{sys.executable}\n"
            "import json, sys\n"
            "from pathlib import Path\n"
            "Path('called.json').write_text(json.dumps(sys.argv[1:]))\n"
            "if sys.argv[1] == 'init':\n"
            f"    Path('shorebird.yaml').write_text('app_id: {self.app_id}\\n')\n"
            "    Path('pubspec.yaml').write_text('flutter:\\n  assets:\\n    - shorebird.yaml\\n')\n"
        )
        self.cli.chmod(0o755)
        self.environment = dict(os.environ, SHOREBIRD_BIN=str(self.cli))

    def run_script(self, *arguments):
        return subprocess.run(
            ["bash", str(self.script), *arguments],
            env=self.environment,
            capture_output=True,
            text=True,
        )

    def configure(self, *, app_id=None, auto_update="false", asset=True):
        (self.root / "shorebird.yaml").write_text(
            f"app_id: {app_id or self.app_id}\nauto_update: {auto_update}\n"
        )
        (self.root / "pubspec.yaml").write_text(
            "flutter:\n  assets:\n"
            + ("    - shorebird.yaml\n" if asset else "    - existing.json\n")
        )

    def test_unbound_release_stops_before_calling_cli(self):
        result = self.run_script("release", "android")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("尚未绑定", result.stderr)
        self.assertFalse((self.root / "called.json").exists())

    def test_invalid_config_stops_before_calling_cli(self):
        for configuration in [
            {"app_id": "not-an-app-id"},
            {"app_id": "00000000-0000-0000-0000-000000000000"},
            {"auto_update": "true"},
            {"asset": False},
        ]:
            with self.subTest(configuration=configuration):
                self.configure(**configuration)
                result = self.run_script("release", "ios")
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((self.root / "called.json").exists())

    def test_release_pins_project_flutter_and_preserves_build_arguments(self):
        self.configure()
        result = self.run_script(
            "release", "android", "--", "--dart-define=LABEL=含 空格"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((self.root / "called.json").read_text()),
            [
                "release", "android", "--flutter-version=3.47.5",
                "--", "--dart-define=LABEL=含 空格",
            ],
        )

    def test_patch_targets_explicit_release_and_staging_track(self):
        self.configure()
        result = self.run_script("patch", "ios", "0.1.0+2", "--track", "staging")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads((self.root / "called.json").read_text()),
            ["patch", "ios", "--release-version=0.1.0+2", "--track", "staging"],
        )

    def test_patch_rejects_implicit_or_latest_release(self):
        self.configure()
        for version in [[], ["latest"], ["--track"], ["0.1.0"]]:
            with self.subTest(version=version):
                result = self.run_script("patch", "android", *version)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("完整基础版本", result.stderr)
                self.assertFalse((self.root / "called.json").exists())

    def test_init_keeps_cli_app_id_and_disables_engine_auto_updates(self):
        result = self.run_script("init")
        self.assertEqual(result.returncode, 0, result.stderr)
        config = (self.root / "shorebird.yaml").read_text()
        self.assertIn(f"app_id: {self.app_id}", config)
        self.assertIn("auto_update: false", config)
        self.assertEqual(self.run_script("validate").returncode, 0)

    def test_init_does_not_replace_existing_app_binding(self):
        self.configure()
        before = (self.root / "shorebird.yaml").read_text()
        result = self.run_script("init")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.root / "shorebird.yaml").read_text(), before)
        self.assertFalse((self.root / "called.json").exists())


if __name__ == "__main__":
    unittest.main()
