# Eva Linux audit fixes and website update

## Scope

Resolve the 12 findings from the repository audit, add isolated regression
tests, correct the documentation, and publish the changes to Eva Linux and
the AmanicX overview. Preserve the existing website design.

## Decisions

- Never run the installer, package transactions, sudo, or service changes on
  the development host. Exercise system boundaries with temporary fixtures.
- Replace passwordless `cp` with a root-owned helper accepting only the
  literal targets `sddm` and `grub`. Pass image bytes on stdin, not paths.
  Decode images as the user; write atomically through trusted directory
  descriptors without following symlinks. Limit the sudo grant to the
  installing user and remove the vulnerable legacy rule during installation.
- Snapshot symlinked configuration contents, not just symlinks.
- Skip unavailable optional themes honestly; do not claim a successful
  Plymouth installation without assets or a successful theme command.
- Retain upstream theme UI; select an Eva wallpaper preset using the theme's
  own metadata.
- Keep the website's existing static build and shared styles. Show dated
  repository updates newest first, distinct from tagged releases.
- Use ordinary HTTPS Git pushes, never force-push. Check remote divergence
  before publishing. Publish the user-requested annotated `v2.1` tag with
  release notes and a bug-fix summary in the commit message.

## Ordered slices

1. Wallpaper privilege boundary and sync failures.
2. Bootstrap and final verification.
3. Backup snapshots and installed launch/restore helpers.
4. SDDM, image dependencies, Plymouth, and display-manager consent.
5. Keybind replacement and portable desktop defaults.
6. README and current installer/restoration/security documentation.
7. Main-site overview, Eva Linux page, regression checks, and browser review.
8. Review, commit, push both repositories, verify published content.

## Verification

- Python `unittest` regression tests, using temporary homes and fake system
  commands; real `niri validate` for isolated configuration edits.
- Bash/Python/JSON/TOML/JavaScript syntax checks and `git diff --check`.
- Website's existing `npm test` and build command; browser checks at desktop
  and mobile widths.
- Full privileged install and boot testing remain an Arch VM/hardware task.

## Risks

- Root helper: adversarial path/symlink/input tests before publication.
- Existing installations: document removal/replacement of the insecure
  sudoers rule; a Git pull alone does not modify installed system files.
- Website build: inspect generator inputs before editing generated pages.
- GitHub authentication/deployment: report actual failures without reading
  credentials or claiming an unverified deployment.
