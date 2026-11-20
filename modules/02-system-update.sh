#!/usr/bin/env bash
# ==============================================================================
#  [02] Safe System Update & Multilib Configuration
# ==============================================================================

set -Eeuo pipefail

run_system_update() {
    step_header 3 14 "System Update & Base Repositories"

    if [[ "${OPT_SKIP_UPDATE:-0}" == "1" ]]; then
        step_info "System update skipped via --skip-update flag"
        return 0
    fi

    # 1. Connectivity Check
    step_info "Checking internet connectivity..."
    if ! curl -s --connect-timeout 5 https://archlinux.org >/dev/null && \
       ! curl -s --connect-timeout 5 https://google.com >/dev/null; then
        step_error "No active internet connection detected. Please verify your network."
        exit 1
    fi
    step_success "Internet connection verified"

    # 2. Check & Enable Multilib if on Arch
    if [[ "${IS_ARCH_COMPATIBLE}" -eq 1 && -f /etc/pacman.conf ]]; then
        if grep -qE '^#\[multilib\][[:space:]]*$' /etc/pacman.conf 2>/dev/null; then
            step_info "Enabling multilib repository in /etc/pacman.conf..."
            sudo sed -i '/^#\[multilib\][[:space:]]*$/{s/^#//;n;s/^#//;}' /etc/pacman.conf
            step_success "Multilib repository enabled"
        fi
    fi

    # 3. Synchronize Databases & Perform Full Upgrade (No Partial Upgrades)
    step_info "Running system upgrade (pacman -Syu)..."
    if ! sudo pacman -Syu --needed --noconfirm base-devel git curl wget jq; then
        step_error "System update failed. To protect your installation, aborting before desktop setup."
        exit 1
    fi
    step_success "System update completed successfully"
}
