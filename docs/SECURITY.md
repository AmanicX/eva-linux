# Wallpaper security upgrade — v2.1

## Existing installations

The v2.0 wallpaper module installed `/etc/sudoers.d/eva-wallpaper-sync`,
granting all users passwordless `cp` with wildcard arguments. That rule can
be abused to redirect root writes and read privileged source files.

A Git pull does **not** remove an already-installed rule. Before running the
old wallpaper synchronizer again:

```bash
systemctl --user disable --now eva-wallpaper-sync.service
sudo rm -f -- /etc/sudoers.d/eva-wallpaper-sync
```

Review the updated installer, preserve your configuration, and rerun setup
from v2.1 to install the new helper and permission rule. Setup may overwrite
desktop configuration; keep its backup enabled. The updated wallpaper module
also removes the legacy rule before installing its replacement.

If an untrusted user had access while the old rule was installed, removing
it does not undo possible compromise. Review system integrity and exposed
credentials before relying on the machine.

## New boundary

- `/usr/local/libexec/eva-wallpaper-install` is root-owned and runs Python in
  isolated mode. Its only arguments are the literal words `sddm` or `grub`.
- The installing user's sudoers entry permits only these two commands.
  There is no arbitrary source path, destination path, option list, or config
  file supplied to the privileged helper.
- The user process decodes, scales, and encodes the image. The helper reads
  at most 64 MiB from stdin and checks the expected JPEG/PNG signature without
  invoking a privileged image decoder.
- The helper walks root-owned, non-user-writable directories using
  `O_NOFOLLOW`, refuses non-regular destination entries, and atomically
  replaces only the two fixed background filenames.
- Wallpaper changes never run `grub-mkconfig`.

This is a restricted image-write capability, not a claim that the desktop
installer is risk-free. No privileged installation was performed by the
repository regression tests.
