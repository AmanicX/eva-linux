# Backup and Restoration Guide

Eva Linux creates timestamped backups of all existing desktop configurations before making changes.

---

## Location of Backups

Backups are stored in:
```
~/eva_backups/backup_YYYYMMDD_HHMMSS/
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
