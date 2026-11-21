# Eva Linux v2.1 desktop installer

Eva Linux configures an existing x86_64 Arch installation. It does not create
an ISO, partition disks, install a base OS, or replace the bootloader.

## Entry points

- `install.sh`: piped bootstrap or local checkout detection; requires Git.
- `setup.sh`: forwards CLI arguments to `bin/eva-installer`.
- `bin/eva-installer`: loads the shared library and runs `modules/00`–`14`.

Run as a regular sudo-capable user, not through `sudo ./setup.sh`.

```bash
./setup.sh --help
./setup.sh
```

Options: `--yes`/`-y`, `--skip-update`, `--skip-backup`, `--help`/`-h`.
`--yes` selects recommended choices; it does not bypass sudo authentication.
`--skip-update` assumes the machine is already fully upgraded. Partial Arch
upgrades are not supported.

## Pipeline

1. Detect distribution, architecture, GPU, bootloader, and display manager.
2. Offer independent configuration snapshots and write a manifest.
3. Upgrade the system and install base build tools unless skipped.
4. Detect or build yay/paru, then offer a browser.
5. Install the desktop stack, Python/Pillow, fonts, and greeter dependencies.
6. Deploy Niri, Noctalia, Kitty, LazyVim, GTK, and Fastfetch settings. Existing
   files are overwritten; declining backup does not protect them.
7. Install keybind, restore, and browser helpers and generate the overlay data.
8. Offer SDDM switching and SilentSDDM theming. Select `configs/eva.conf` in
   theme metadata; only wallpaper settings differ from the upstream preset.
9. Offer HyperFluent theming only if GRUB is already detected. Back up GRUB
   defaults and stage generated configuration before replacing `grub.cfg`.
10. Skip Plymouth because this release ships no Eva splash theme.
11. Install the restricted wallpaper helper, replace the old broad sudoers
    rule, validate the new per-user rule with `visudo`, and enable the watcher.
12. Offer the optional Eva AI app.
13. Enable services. A consented display-manager switch takes effect at the
    next boot without stopping the current session.
14. Run every final check, summarize results, and return failure if required
    checks fail. Declined optional themes are not required checks.

Logs: `~/.local/state/eva/install-*.log`.
Backups and rollback limits: [RESTORATION.md](RESTORATION.md).
Existing installations: [SECURITY.md](SECURITY.md).

## Validation

```bash
python3 -m unittest discover -s tests -v
niri validate -c configs/niri/config.kdl
```

The suite uses temporary directories and stubbed privileged boundaries. It
does not install packages, alter services, or modify the host bootloader.
Pillow and Niri are required for the image and real-config regression tests.
Before deploying to a real workstation, test a complete install and reboot
in a disposable Arch VM. NVIDIA/Intel hardware and system-specific service
conflicts require separate validation.
