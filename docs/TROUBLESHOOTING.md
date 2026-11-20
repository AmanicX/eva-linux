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

### 3. Sudo password prompts on wallpaper change
Ensure the sudoers permission rule is installed:
```bash
sudo cat /etc/sudoers.d/eva-wallpaper-sync
```

### 4. Audio output issues
Verify PipeWire and WirePlumber:
```bash
systemctl --user status pipewire pipewire-pulse wireplumber
```
Use `pavucontrol` to select your default audio sink.
