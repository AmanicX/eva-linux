# Eva Linux v2.1 Architecture

Eva Linux is an automated desktop setup installer that transforms a minimal or existing Arch Linux installation into a fully-configured, high-performance Wayland environment.

Eva Linux is **NOT an ISO**. It is a script-based system orchestrator and configuration framework.

---

## 1. Directory Layout

```
eva-linux/
├── install.sh                  # Bootstrap curl script
├── setup.sh                    # Primary CLI entrypoint
├── bin/
│   ├── eva-installer           # Core orchestration engine
│   ├── eva-keybinds-manager    # Python Niri keybind parser & validator
│   ├── eva-keybinds-start      # Quickshell daemon launcher
│   ├── eva-keybinds-toggle     # Overlay toggle script
│   ├── eva-wallpaper-sync      # Background wallpaper synchronizer
│   ├── eva-wallpaper-install   # Restricted privileged image writer
│   ├── eva-restore             # Configuration rollback tool
│   └── eva-default-browser     # Browser launcher wrapper
├── modules/                    # Isolated, idempotent installation steps
│   ├── lib.sh                  # Logging, styling, error traps, sudo keepalive
│   ├── 00-detect.sh            # OS, CPU, GPU, DM, and bootloader detection
│   ├── 01-backup.sh            # Timestamped configs backup & manifest generator
│   ├── 02-system-update.sh     # Safe full system upgrade (pacman -Syu)
│   ├── 03-aur-helper.sh        # yay/paru detection, verification & installation
│   ├── 04-browser.sh           # Interactive browser selection & XDG integration
│   ├── 05-desktop-packages.sh  # Pacman & AUR package installs
│   ├── 06-desktop-config.sh    # Niri, Noctalia 5, Kitty, Neovim, GTK deployment
│   ├── 07-keybind-popup.sh     # Quickshell overlay & Niri layer-rule setup
│   ├── 08-sddm.sh              # SilentSDDM theme installation & background config
│   ├── 09-grub.sh              # HyperFluent GRUB theme deployment
│   ├── 10-plymouth.sh          # Plymouth splash configuration
│   ├── 11-wallpaper.sh         # Wallpaper deployment & watcher user service
│   ├── 12-eva-ai.sh            # Optional Eva AI Chatbot integration
│   ├── 13-services.sh          # Systemd system & user service activation
│   └── 14-verify.sh            # Sanity checks and post-install validation
├── configs/                    # Master configuration templates
├── themes/                     # Upstream SDDM and GRUB themes; no Eva Plymouth assets
├── assets/                     # Genuine screenshots & wallpapers
├── index.html                  # Official Eva Linux v2 Website
└── README.md                   # Complete user documentation
```

The website generator lives in the `amanicx.github.io` repository. Its Eva
Linux pages are synchronized here after building; change the generator's
source/data to prevent future deployments reverting page edits.

---

## 2. Core Components

| Component | Upstream Source | Role |
|---|---|---|
| **Niri** | [YaLixDee/niri](https://github.com/YaLixDee/niri) | Scrollable tiling Wayland compositor |
| **Noctalia 5** | [noctalia-dev/noctalia](https://github.com/noctalia-dev/noctalia) | Desktop shell, capsule bar, control center |
| **Quickshell** | [outfoxxed/quickshell](https://github.com/outfoxxed/quickshell) | Native Wayland QML toolkit for overlays |
| **Kitty** | [kovidgoyal/kitty](https://github.com/kovidgoyal/kitty) | GPU-accelerated terminal with blur and Noctalia palette sync |
| **Neovim** | [neovim/neovim](https://github.com/neovim/neovim) | IDE editor with LazyVim starter |
| **SilentSDDM** | [uiriansan/SilentSDDM](https://github.com/uiriansan/SilentSDDM) | Minimalist login greeter |
| **HyperFluent** | [Coopydood/HyperFluent-GRUB-Theme](https://github.com/Coopydood/HyperFluent-GRUB-Theme) | Fluent GRUB bootloader theme |
