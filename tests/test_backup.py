import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BackupTests(unittest.TestCase):
    def test_symlinked_config_and_nested_files_are_independent_snapshots(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            original = home / "dotfiles/niri"
            original.mkdir(parents=True)
            config = original / "config.kdl"
            config.write_text("original")
            external = home / "external.kdl"
            external.write_text("included")
            (original / "included.kdl").symlink_to(external)
            (home / ".config").mkdir()
            (home / ".config/niri").symlink_to(original, target_is_directory=True)
            script = """
                source modules/01-backup.sh
                step_header() { :; }
                step_info() { :; }
                step_success() { :; }
                ask_confirm() { return 0; }
                run_backup
            """
            result = subprocess.run(
                ["bash", "-c", script], cwd=ROOT,
                env={**os.environ, "HOME": directory}, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            backup = next((home / "eva_backups").glob("backup_*"))
            config.write_text("overwritten")
            external.write_text("overwritten")
            self.assertFalse((backup / "config/niri").is_symlink())
            self.assertEqual((backup / "config/niri/config.kdl").read_text(), "original")
            self.assertEqual((backup / "config/niri/included.kdl").read_text(), "included")

    def test_restore_works_without_existing_config_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            backup = home / "eva_backups/backup_fixture"
            (backup / "config/niri").mkdir(parents=True)
            (backup / "config/niri/config.kdl").write_text("saved")
            result = subprocess.run(
                ["bash", str(ROOT / "bin/eva-restore"), str(backup)], input="y\n",
                env={**os.environ, "HOME": directory}, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / ".config/niri/config.kdl").read_text(), "saved")

    def test_restore_and_browser_helpers_are_installed(self):
        deployment = (ROOT / "modules/07-keybind-popup.sh").read_text()
        self.assertIn('${script_root}/bin/eva-restore', deployment)
        self.assertIn('${script_root}/bin/eva-default-browser', deployment)
        bindings = (ROOT / "configs/niri/keybinds.kdl").read_text()
        self.assertIn('spawn "eva-default-browser"', bindings)


if __name__ == "__main__":
    unittest.main()
