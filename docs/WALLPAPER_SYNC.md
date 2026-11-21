# Wallpaper Synchronization Architecture

The user-session watcher checks Noctalia's wallpaper every three seconds and
synchronizes configured Eva SilentSDDM and HyperFluent GRUB backgrounds.
See [SECURITY.md](SECURITY.md) before upgrading an existing v2.0 installation.

---

## Technical Flow

1. **Detection**:
   - `noctalia msg wallpaper-get` reports the active wallpaper path.
    - The `eva-wallpaper-sync --watch` user service polls `~/.local/state/noctalia/settings.toml` and detects changes to the image. Failed syncs retry after 30 seconds.
2. **SilentSDDM (Display Manager)**:
    - The user process converts the image to JPEG. A restricted helper atomically installs the bytes at `/usr/share/sddm/themes/silent/backgrounds/eva-wallpaper.jpg`.
    - The theme's `metadata.desktop` selects `configs/eva.conf`, which names `eva-wallpaper.jpg` in both background sections.
   - **Zero UI changes:** Only the background image is changed; SilentSDDM's upstream layout, fonts, and controls remain 100% intact.
3. **HyperFluent (GRUB Bootloader)**:
    - The user process converts the wallpaper to PNG and streams it to the same helper for `/boot/grub/themes/hyperfluent/background.png`.
    - **No `grub-mkconfig` required:** HyperFluent's `theme.txt` already references `background.png`. Replacing the file updates the boot screen instantly on next reboot without touching `grub.cfg`.

The helper accepts only `sddm` or `grub`; it never accepts file paths from the
caller or uses shared `/tmp` image files. Missing optional themes are skipped.
Failures in configured themes produce nonzero status. Output images are
limited to 3840×2160 and input images to 36 megapixels.
