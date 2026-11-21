# Backup and Restoration Guide

Eva Linux offers timestamped backups of the desktop configuration directories
listed in `modules/01-backup.sh`. Backups are enabled by default but can be
declined or disabled with `--skip-backup`.

---

## Location of Backups

Backups are stored in:
```
~/eva_backups/backup_YYYYMMDD_HHMMSS_XXXXXX/
```

Each backup directory contains:
- `config/`: Copies of `~/.config/` items (Niri, Noctalia, Kitty, Neovim, GTK, Quickshell, etc.)
- `state/`: Copies of `~/.local/state/noctalia`
- `system/`: Copies of `/etc/sddm.conf` and `/etc/default/grub`
- `manifest.txt`: List of all archived files with timestamps

---

## How to Restore

To restore previous configurations at any time, run:

```bash
eva-restore
```

The interactive menu will display all available backups. Select your desired backup number and confirm to restore.

Symlinked directories and nested files are copied as independent contents.
Restoring produces ordinary directories, not the original symlink layout.
One snapshot's saved user configurations are restored together; there is no
per-component selection menu.

`system/` files are reference copies only. `eva-restore` does not automatically
restore GRUB, SDDM drop-ins, sudoers, installed packages, or service enablement.
It is not a full-system rollback. Review system changes separately.
