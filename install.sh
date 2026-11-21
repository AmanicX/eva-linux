#!/usr/bin/env bash
# ==============================================================================
#  ✦ Eva Linux v2.1 — Quick Bootstrap Installer
#  https://github.com/AmanicX/eva-linux
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh | bash
#    or:
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh)"
# ==============================================================================

set -Eeuo pipefail

# Keep stdin attached to the script for `curl | bash`. Interactive prompts in
# the installer explicitly read /dev/tty; redirecting here discards script input.

# Palette
if [[ -t 1 ]]; then
    C_CRIMSON="\033[38;2;208;102;102m"
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_RED="\033[38;2;240;80;80m"
    C_MUTED="\033[38;2;142;158;169m"
else
    C_CRIMSON=""
    C_RESET=""
    C_BOLD=""
    C_RED=""
    C_MUTED=""
fi

# Root check
if [[ ${EUID} -eq 0 ]]; then
    printf "${C_RED}${C_BOLD}Error:${C_RESET} Do not run this installer directly as root.\nPlease run as your regular user with sudo privileges:\n  curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh | bash\n" >&2
    exit 1
fi

# Local repository detection (if cloned locally)
SCRIPT_DIR=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P)"
fi
if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/setup.sh" && -d "${SCRIPT_DIR}/modules" ]]; then
    exec bash "${SCRIPT_DIR}/setup.sh" "$@"
fi

printf "\n${C_CRIMSON}${C_BOLD}✦ Eva Linux v2.1${C_RESET} — Fetching installer repository...\n"
if ! command -v git >/dev/null 2>&1; then
    printf 'Git is required. Install it with: sudo pacman -S --needed git\n' >&2
    exit 1
fi
CLONE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eva-linux.XXXXXXXX")"

if ! git clone --depth 1 "https://github.com/AmanicX/eva-linux.git" "${CLONE_DIR}"; then
    printf "${C_RED}Failed to clone repository from GitHub.${C_RESET}\n" >&2
    exit 1
fi

cd "${CLONE_DIR}"
exec bash ./setup.sh "$@"
