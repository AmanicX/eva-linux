#!/usr/bin/env bash
# ==============================================================================
#  ✦ Eva Linux v2 Stable — Quick Bootstrap Installer
#  https://github.com/AmanicX/eva-linux
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh | bash
#    or:
#    bash -c "$(curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh)"
# ==============================================================================

set -Eeuo pipefail

# Re-attach standard input to terminal if piped through curl
if [[ ! -t 0 && -e /dev/tty ]]; then
    exec < /dev/tty
fi

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
if [[ ${EUID} -eq 0 && -z ${SUDO_USER:-} ]]; then
    printf "${C_RED}${C_BOLD}Error:${C_RESET} Do not run this installer directly as root.\nPlease run as your regular user with sudo privileges:\n  curl -fsSL https://raw.githubusercontent.com/AmanicX/eva-linux/main/install.sh | bash\n" >&2
    exit 1
fi

# Local repository detection (if cloned locally)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
if [[ -n "${SCRIPT_DIR}" && -f "${SCRIPT_DIR}/setup.sh" && -d "${SCRIPT_DIR}/modules" ]]; then
    exec bash "${SCRIPT_DIR}/setup.sh" "$@"
fi

printf "\n${C_CRIMSON}${C_BOLD}✦ Eva Linux v2 Stable${C_RESET} — Fetching installer repository...\n"
CLONE_DIR="/tmp/eva-linux-$(date +%s)"
rm -rf "${CLONE_DIR}"

if ! git clone --depth 1 "https://github.com/AmanicX/eva-linux.git" "${CLONE_DIR}"; then
    printf "${C_RED}Failed to clone repository from GitHub.${C_RESET}\n" >&2
    exit 1
fi

cd "${CLONE_DIR}"
exec bash ./setup.sh "$@"
