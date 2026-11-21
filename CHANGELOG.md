# Changelog

## v2.1 — Security and reliability

### Security

- Replace the all-user passwordless `cp` wildcard with an installing-user-only
  grant for a root-owned, isolated helper with two fixed image destinations.
- Convert images without root privileges; pass bounded image bytes on stdin.
  Reject symlink destinations and writable directory chains; replace images
  atomically without shared predictable temporary files.
- Remove the legacy broad sudoers rule when the new wallpaper module runs.
  Existing installations must follow [the upgrade instructions](docs/SECURITY.md).

### Fixed

- Keep `curl … | bash` reading the installer rather than terminal input.
- Complete all final verification checks instead of exiting after the first
  post-increment; report required failures with a nonzero exit status.
- Snapshot symlinked dotfile contents into private, independent backup folders.
- Install the missing restore/browser helpers and repair the browser shortcut.
- Build SilentSDDM's wallpaper preset from the shipped default and select it
  in theme metadata.
- Install Pillow and the missing X11/Qt greeter dependencies.
- Stage GRUB configuration before replacing the active file; restore defaults
  if generation fails.
- Report failed wallpaper synchronization instead of always returning success;
  retry watcher failures and skip unconfigured optional themes.
- Leave Plymouth unchanged when no Eva splash assets are available.
- Respect display-manager consent, avoid stopping the active session, and
  restore the previous manager if SDDM enablement fails.
- Make shortcut Replace disable the old assignment; preserve Swap, reject
  stale targets, validate staged edits, and roll back cache-write failures.
- Remove personal wallpaper/monitor defaults and hidden writes into the
  developer's AstraOS checkout.

### Documentation and verification

- Correct fullscreen, floating, and workspace shortcuts.
- Replace obsolete ISO installer documentation with the actual desktop setup
  workflow, security upgrade steps, and restoration boundaries.
- Add isolated regression tests and publish the v2.1 overview and release notes.
- Full privileged installation, reboot, and GPU-specific testing remain
  separate Arch VM/hardware checks.
