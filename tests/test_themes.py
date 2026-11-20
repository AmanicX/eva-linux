import configparser
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
STUB_LOGGING = """
    step_header() { :; }
    step_info() { echo "$*"; }
    step_warn() { echo "$*"; }
    step_success() { echo "SUCCESS: $*"; }
    step_error() { echo "ERROR: $*"; }
"""


class ThemeTests(unittest.TestCase):
    def test_sddm_preset_uses_shipped_config_and_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            theme = Path(directory)
            (theme / "configs").mkdir()
            shutil.copy2(ROOT / "themes/sddm/silent/configs/default.conf", theme / "configs")
            shutil.copy2(ROOT / "themes/sddm/silent/metadata.desktop", theme)
            script = """
                source modules/08-sddm.sh
                sudo() { "$@"; }
                configure_sddm_preset "$1"
            """
            result = subprocess.run(
                ["bash", "-c", script, "test", directory], cwd=ROOT,
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            preset = configparser.ConfigParser()
            preset.read(theme / "configs/eva.conf")
            self.assertEqual(preset["LockScreen"]["background"], '"eva-wallpaper.jpg"')
            self.assertEqual(preset["LoginScreen"]["background"], '"eva-wallpaper.jpg"')
            self.assertIn("ConfigFile=configs/eva.conf", (theme / "metadata.desktop").read_text())

    def test_skipped_sddm_is_not_enabled_just_because_installed(self):
        script = """
            source modules/13-services.sh
            ENABLE_SDDM=0 DETECTED_DM=gdm
            sudo() { echo "SUDO $*"; }
            systemctl() { return 0; }
        """ + STUB_LOGGING + "\nrun_services\n"
        result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("enable sddm", result.stdout)
        self.assertNotIn("disable gdm", result.stdout)

    def test_switching_manager_does_not_stop_running_session(self):
        script = """
            source modules/13-services.sh
            ENABLE_SDDM=1 DETECTED_DM=gdm
            sudo() { echo "SUDO $*"; }
            systemctl() { return 0; }
        """ + STUB_LOGGING + "\nrun_services\n"
        result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("disable gdm.service", result.stdout)
        self.assertIn("enable sddm.service", result.stdout)
        self.assertNotIn("--now gdm", result.stdout)
        self.assertNotIn("stop gdm", result.stdout)

    def test_failed_manager_switch_reenables_previous_manager(self):
        script = """
            source modules/13-services.sh
            ENABLE_SDDM=1 DETECTED_DM=lightdm
            sudo() {
                echo "SUDO $*"
                [[ "$*" != "systemctl enable sddm.service" ]]
            }
            systemctl() { return 0; }
        """ + STUB_LOGGING + "\nrun_services\n"
        result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("enable lightdm.service", result.stdout)
        self.assertNotIn("SUCCESS:", result.stdout)

    def test_missing_plymouth_assets_leave_system_unchanged(self):
        script = """
            source modules/10-plymouth.sh
            ask_confirm() { return 0; }
            command() { return 0; }
            sudo() { echo "SUDO $*"; }
        """ + STUB_LOGGING + "\nrun_plymouth\n"
        result = subprocess.run(["bash", "-c", script], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("SUDO ", result.stdout)
        self.assertNotIn("SUCCESS:", result.stdout)
        self.assertIn("Skipping", result.stdout)

    def test_image_and_greeter_dependencies_are_declared(self):
        packages = (ROOT / "modules/05-desktop-packages.sh").read_text()
        for package in ("python-pillow", "xorg-server", "qt6-multimedia-ffmpeg", "qt6-imageformats"):
            self.assertIn(package, packages)


if __name__ == "__main__":
    unittest.main()
