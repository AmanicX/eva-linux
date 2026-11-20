import os
from pathlib import Path
import runpy
import shutil
import subprocess
import tempfile
import tomllib
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
REAL_RUN = subprocess.run


class KeybindTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name)
        for source in (ROOT / "configs/niri").glob("*.kdl"):
            shutil.copy2(source, self.path / source.name)
        self.api = runpy.run_path(str(ROOT / "bin/eva-keybinds-manager"))
        self.globals = self.api["apply_edit"].__globals__
        self.globals.update(
            CONFIG=str(self.path / "keybinds.kdl"),
            NIRI_CONFIG=str(self.path / "config.kdl"),
            OUT=str(self.path / "keybinds.json"),
            REPO_CONFIG=str(self.path / "must-not-be-written.kdl"),
        )
        (self.path / "must-not-be-written.kdl").write_text("untouched")
        self.binds = self.api["parse_file"](self.globals["CONFIG"])
        self.terminal = next(b for b in self.binds if b["key_spec"] == "Mod+Return")
        self.files = next(b for b in self.binds if b["key_spec"] == "Mod+E")

    def safe_run(self, command, **kwargs):
        if command[:2] == ["niri", "validate"]:
            return REAL_RUN(command, **kwargs)
        if command[:2] == ["niri", "msg"]:
            return subprocess.CompletedProcess(command, 0, "", "")
        raise AssertionError(f"Unexpected external command: {command}")

    def test_replace_disables_only_the_conflicting_binding(self):
        with patch("subprocess.run", side_effect=self.safe_run):
            ok, message = self.api["apply_edit"](self.terminal["line_no"], "Mod+E")
        self.assertTrue(ok, message)
        binds = self.api["parse_file"](self.globals["CONFIG"])
        self.assertEqual(sum(b["norm_spec"] == "Mod+E" for b in binds), 1)
        self.assertEqual(len(binds), len(self.binds) - 1)
        self.assertIn('spawn "kitty"', next(b["action"] for b in binds if b["norm_spec"] == "Mod+E"))
        self.assertEqual((self.path / "must-not-be-written.kdl").read_text(), "untouched")

    def test_swap_preserves_both_actions(self):
        with patch("subprocess.run", side_effect=self.safe_run):
            ok, message = self.api["apply_edit"](
                self.terminal["line_no"], "Mod+E", mode="swap",
                swap_line_no=self.files["line_no"],
            )
        self.assertTrue(ok, message)
        binds = self.api["parse_file"](self.globals["CONFIG"])
        self.assertEqual(len(binds), len(self.binds))
        self.assertIn('spawn "nautilus"', next(b["action"] for b in binds if b["norm_spec"] == "Mod+Return"))

    def test_rejected_edit_leaves_live_file_unchanged(self):
        original = Path(self.globals["CONFIG"]).read_bytes()
        with patch("subprocess.run", side_effect=self.safe_run):
            ok, _ = self.api["apply_edit"](self.terminal["line_no"], "Mod+NotARealKeysym123")
        self.assertFalse(ok)
        self.assertEqual(Path(self.globals["CONFIG"]).read_bytes(), original)

    def test_cache_write_failure_rolls_back_live_file(self):
        original = Path(self.globals["CONFIG"]).read_bytes()
        self.globals["generate_json"] = lambda: (_ for _ in ()).throw(OSError("disk full"))
        with patch("subprocess.run", side_effect=self.safe_run):
            ok, message = self.api["apply_edit"](self.terminal["line_no"], "Mod+Alt+T")
        self.assertFalse(ok, message)
        self.assertEqual(Path(self.globals["CONFIG"]).read_bytes(), original)

    def test_stale_swap_line_is_refused(self):
        original = Path(self.globals["CONFIG"]).read_bytes()
        with patch("subprocess.run", side_effect=self.safe_run):
            ok, _ = self.api["apply_edit"](
                self.terminal["line_no"], "Mod+E", mode="swap", swap_line_no=1,
            )
        self.assertFalse(ok)
        self.assertEqual(Path(self.globals["CONFIG"]).read_bytes(), original)

    def test_defaults_have_no_personal_paths_or_monitor_ids(self):
        text = (ROOT / "configs/noctalia/settings.toml").read_text()
        self.assertNotIn("/home/apex", text)
        self.assertNotIn("eDP-1", text)
        self.assertIn("eva-crimson-temple.jpg", text)
        manager = (ROOT / "bin/eva-keybinds-manager").read_text()
        self.assertNotIn("/run/media/apex", manager)

    def test_noctalia_deployment_expands_the_installing_users_home(self):
        home = self.path / "home with spaces"
        home.mkdir()
        script = """
            source modules/06-desktop-config.sh
            step_header() { :; }
            step_info() { :; }
            step_success() { :; }
            step_error() { echo "$*" >&2; }
            ask_confirm() { return 0; }
            xdg-user-dirs-update() { :; }
            run_desktop_config
        """
        result = subprocess.run(
            ["bash", "-c", script], cwd=ROOT,
            env={**os.environ, "HOME": str(home)}, capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        settings = tomllib.loads((home / ".local/state/noctalia/settings.toml").read_text())
        self.assertEqual(
            settings["wallpaper"]["default"]["path"],
            str(home / "Pictures/Wallpapers/eva-crimson-temple.jpg"),
        )


if __name__ == "__main__":
    unittest.main()
