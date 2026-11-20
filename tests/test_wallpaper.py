import io
import os
from pathlib import Path
import runpy
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.api = runpy.run_path(str(ROOT / "bin/eva-wallpaper-sync"))
        self.globals = self.api["sync_all"].__globals__

    def test_backend_failures_produce_nonzero_status(self):
        with tempfile.NamedTemporaryFile() as wallpaper:
            self.globals["sync_sddm"] = lambda _: (False, "denied")
            self.globals["sync_grub"] = lambda _: (False, "denied")
            with patch("sys.stdout", new=io.StringIO()):
                self.assertEqual(self.api["sync_all"](wallpaper.name), 1)

    def test_optional_absent_backends_are_skipped(self):
        with tempfile.NamedTemporaryFile() as wallpaper:
            self.globals["sync_sddm"] = lambda _: (None, "not configured")
            self.globals["sync_grub"] = lambda _: (None, "not configured")
            with patch("sys.stdout", new=io.StringIO()):
                self.assertEqual(self.api["sync_all"](wallpaper.name), 0)

    def test_privileged_sync_passes_bytes_not_source_paths(self):
        from PIL import Image

        with tempfile.TemporaryDirectory() as directory:
            image = Path(directory) / "source.png"
            Image.new("RGB", (2, 2), "red").save(image)
            self.globals["SDDM_THEME_DIR"] = directory
            (Path(directory) / "configs").mkdir()
            (Path(directory) / "configs/eva.conf").write_text("[LockScreen]\n")
            with patch("subprocess.run") as run:
                run.return_value = subprocess.CompletedProcess([], 0, b"", b"")
                ok, _ = self.api["sync_sddm"](str(image))
                self.assertTrue(ok)
                args, kwargs = run.call_args
                self.assertEqual(
                    args[0],
                    ["sudo", "-n", "/usr/local/libexec/eva-wallpaper-install", "sddm"],
                )
                self.assertIsInstance(kwargs["input"], bytes)
                self.assertNotIn(str(image), args[0])

    def test_rule_does_not_grant_cp_or_all_users(self):
        source = (ROOT / "modules/11-wallpaper.sh").read_text()
        self.assertNotIn("NOPASSWD: /usr/bin/cp", source)
        self.assertNotIn("ALL ALL =", source)
        self.assertIn("visudo", source)


class WallpaperInstallerTests(unittest.TestCase):
    def setUp(self):
        self.api = runpy.run_path(str(ROOT / "bin/eva-wallpaper-install"))

    def test_rejects_paths_and_extra_arguments(self):
        result = subprocess.run(
            ["python3", str(ROOT / "bin/eva-wallpaper-install"), "/etc/passwd"],
            input=b"not an image",
            capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_rejects_non_image_and_oversized_data(self):
        validate = self.api["validate_payload"]
        with self.assertRaises(ValueError):
            validate("grub", b"shell commands")
        with self.assertRaises(ValueError):
            validate("sddm", b"\xff\xd8\xff" + b"x" * self.api["MAX_BYTES"])

    def test_rejects_wrong_image_format(self):
        with self.assertRaises(ValueError):
            self.api["validate_payload"]("grub", b"\xff\xd8\xffJPEG")

    def test_atomic_write_does_not_follow_destination_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            victim = path / "victim"
            victim.write_bytes(b"original")
            (path / "background.png").symlink_to(victim)
            fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
            try:
                with self.assertRaises((OSError, ValueError)):
                    self.api["atomic_install"](fd, "background.png", b"image")
            finally:
                os.close(fd)
            self.assertEqual(victim.read_bytes(), b"original")

    def test_atomic_write_uses_public_readable_nonexecutable_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
            try:
                self.api["atomic_install"](fd, "background.png", b"image")
            finally:
                os.close(fd)
            target = Path(directory) / "background.png"
            self.assertEqual(target.read_bytes(), b"image")
            self.assertEqual(target.stat().st_mode & 0o777, 0o644)
            self.assertEqual(len(list(Path(directory).iterdir())), 1)

    def test_rejects_user_writable_directory_chain(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises((OSError, ValueError)):
                self.api["open_trusted_directory"](directory)


if __name__ == "__main__":
    unittest.main()
