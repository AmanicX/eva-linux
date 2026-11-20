# Wallpaper Synchronization Architecture

When you change your desktop wallpaper through Noctalia (`Super + Alt + Space` or `noctalia msg wallpaper-set`), Eva Linux automatically synchronizes the background to your login greeter and bootloader.

---

## Technical Flow

1. **Detection**:
   - `noctalia msg wallpaper-get` reports the active wallpaper path.
   - The `eva-wallpaper-sync --watch` user service listens for changes in `~/.local/state/noctalia/settings.toml`.
2. **SilentSDDM (Display Manager)**:
   - The image is copied to `/usr/share/sddm/themes/silent/backgrounds/eva-wallpaper.jpg`.
   - The active preset (`configs/eva.conf`) points to this background.
   - **Zero UI changes:** Only the background image is changed; SilentSDDM's upstream layout, fonts, and controls remain 100% intact.
3. **HyperFluent (GRUB Bootloader)**:
   - The wallpaper is converted to PNG format and copied to `/boot/grub/themes/hyperfluent/background.png`.
   - **No `grub-mkconfig` required:** HyperFluent's `theme.txt` already references `background.png`. Replacing the file updates the boot screen instantly on next reboot without touching `grub.cfg`.
