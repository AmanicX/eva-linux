#!/usr/bin/env bash
# ==============================================================================
#  ✦ Eva Linux v2 Stable — Shared Installer Library
# ==============================================================================

set -Eeuo pipefail

# Terminal colors
if [[ -t 1 ]]; then
    C_RESET="\033[0m"
    C_BOLD="\033[1m"
    C_DIM="\033[2m"
    C_CYAN="\033[38;2;94;230;242m"
    C_CRIMSON="\033[38;2;208;102;102m"
    C_GOLD="\033[38;2;230;164;90m"
    C_GREEN="\033[38;2;80;227;145m"
    C_RED="\033[38;2;240;80;80m"
    C_YELLOW="\033[38;2;245;200;80m"
    C_MUTED="\033[38;2;142;158;169m"
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_CYAN=""
    C_CRIMSON=""
    C_GOLD=""
    C_GREEN=""
    C_RED=""
    C_YELLOW=""
    C_MUTED=""
fi

LOG_DIR="${HOME}/.local/state/eva"
LOG_FILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

log() {
    local level="$1"
    shift
    local msg="$*"
    printf '[%s] [%s] %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "${level}" "${msg}" >> "${LOG_FILE}"
}

step_header() {
    local num="$1" total="$2" title="$3"
    printf "\n${C_CRIMSON}${C_BOLD}[%s/%s]${C_RESET} ${C_BOLD}%s${C_RESET}\n" "${num}" "${total}" "${title}"
    printf "${C_MUTED}%s${C_RESET}\n" "─────────────────────────────────────────────────────────────────"
    log "STEP" "[${num}/${total}] ${title}"
}

step_info() {
    printf "  ${C_CYAN}ℹ${C_RESET} %s\n" "$*"
    log "INFO" "$*"
}

step_success() {
    printf "  ${C_GREEN}✓${C_RESET} %s\n" "$*"
    log "SUCCESS" "$*"
}

step_warn() {
    printf "  ${C_YELLOW}⚠ %s${C_RESET}\n" "$*"
    log "WARN" "$*"
}

step_error() {
    printf "  ${C_RED}✖ Error: %s${C_RESET}\n" "$*" >&2
    log "ERROR" "$*"
}

ask_confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local yn="[Y/n]"
    [[ "${default}" == "n" ]] && yn="[y/N]"

    if [[ "${OPT_NON_INTERACTIVE:-0}" == "1" ]]; then
        [[ "${default}" == "y" ]] && return 0 || return 1
    fi

    local reply
    while true; do
        printf "  ${C_GOLD}?${C_RESET} %s ${C_MUTED}%s${C_RESET} " "${prompt}" "${yn}"
        read -r reply </dev/tty || reply="${default}"
        reply="$(printf '%s' "${reply}" | tr '[:upper:]' '[:lower:]')"
        [[ -z "${reply}" ]] && reply="${default}"
        if [[ "${reply}" == "y" || "${reply}" == "yes" ]]; then
            return 0
        elif [[ "${reply}" == "n" || "${reply}" == "no" ]]; then
            return 1
        fi
    done
}

require_sudo() {
    if ! sudo -v; then
        step_error "Sudo privileges are required to proceed."
        exit 1
    fi
    # Keep sudo alive in background
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_PID=$!
    trap 'kill "${SUDO_PID:-}" 2>/dev/null || true' EXIT
}
