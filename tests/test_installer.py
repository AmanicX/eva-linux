import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def test_piped_bootstrap_reaches_setup_not_terminal_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            fake_bin = home / "bin"
            fake_bin.mkdir()
            git = fake_bin / "git"
            git.write_text(
                '#!/bin/bash\n'
                'destination="${@: -1}"\n'
                'mkdir -p "$destination"\n'
                'printf \'echo AUDIT_SETUP_REACHED\\n\' > "$destination/setup.sh"\n'
            )
            git.chmod(0o755)
            read_fd, write_fd = os.pipe()
            os.write(write_fd, (ROOT / "install.sh").read_bytes())
            os.close(write_fd)
            pid, terminal = pty.fork()
            if pid == 0:
                os.chdir(directory)
                os.dup2(read_fd, 0)
                os.close(read_fd)
                os.environ["PATH"] = f"{fake_bin}:/usr/bin:/bin"
                os.environ["HOME"] = directory
                os.environ["TMPDIR"] = directory
                os.execv("/bin/bash", ["bash"])
            os.close(read_fd)
            output = b""
            try:
                os.write(terminal, b"echo AUDIT_TTY_WAS_EXECUTED; exit 0\n")
                while select.select([terminal], [], [], 3)[0]:
                    try:
                        data = os.read(terminal, 65536)
                    except OSError:
                        break
                    if not data:
                        break
                    output += data
            finally:
                finished, _ = os.waitpid(pid, os.WNOHANG)
                if not finished:
                    os.kill(pid, signal.SIGTERM)
                    os.waitpid(pid, 0)
                os.close(terminal)
            self.assertIn(b"AUDIT_SETUP_REACHED", output)
            self.assertNotIn(b"\r\nAUDIT_TTY_WAS_EXECUTED\r\n", output)

    def run_verification(self, successful):
        # All inspected commands are shell functions; no host service/config changes.
        script = """
            source modules/14-verify.sh
            C_CRIMSON= C_BOLD= C_RESET= C_MUTED= C_GREEN= C_YELLOW=
            LOG_FILE=/dev/null
            command() { return STATUS; }
            test() { return STATUS; }
            niri() { return STATUS; }
            run_verify
        """.replace("STATUS", "0" if successful else "1")
        return subprocess.run(
            ["bash", "-c", script], cwd=ROOT,
            capture_output=True, text=True,
        )

    def test_verification_runs_all_checks_without_errexit_abort(self):
        result = self.run_verification(True)
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("Verification Results:", result.stdout)
        self.assertIn("Installation Completed Successfully", result.stdout)

    def test_failed_verification_runs_to_summary_and_returns_failure(self):
        result = self.run_verification(False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Verification Results:", result.stdout)
        self.assertNotIn("Installation Completed Successfully", result.stdout)


if __name__ == "__main__":
    unittest.main()
