# Troubleshooting & FAQ

### 1. Niri configuration validation fails
Run:
```bash
niri validate -c ~/.config/niri/config.kdl
```
This will report any syntax errors in `config.kdl` or included `.kdl` files.

### 2. Cheatsheet popup does not appear
Check if Quickshell is running:
```bash
eva-keybinds-toggle
```
Or start the daemon manually:
```bash
qs -c keybinds -d
```

### 3. Wallpaper permission failures
For old installations, remove the insecure legacy rule first; see
[SECURITY.md](SECURITY.md). In v2.1, validate the per-user rule and inspect
watcher logs:
```bash
sudo visudo -cf "/etc/sudoers.d/eva-wallpaper-$(id -un)"
journalctl --user -u eva-wallpaper-sync.service -n 50
eva-wallpaper-sync
```
Do not restore the old passwordless `cp` rule. The watcher uses `sudo -n` and
reports permission failure rather than prompting from a background process.

### 4. Audio output issues
Verify PipeWire and WirePlumber:
```bash
systemctl --user status pipewire pipewire-pulse wireplumber
```
Use `pavucontrol` to select your default audio sink.
