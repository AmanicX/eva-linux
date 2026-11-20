#!/usr/bin/env bash
# ==============================================================================
#  [10] Plymouth Boot Splash Setup
# ==============================================================================

set -Eeuo pipefail

run_plymouth() {
    step_header 11 14 "Plymouth Boot Splash Setup"

    if ! command -v plymouth >/dev/null 2>&1; then
        step_info "Plymouth is not installed. Skipping boot splash configuration."
        return 0
    fi

    if ! ask_confirm "Do you want to configure the Eva Linux Plymouth boot splash?" "y"; then
        step_info "Plymouth setup skipped by user."
        return 0
    fi

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"

    # Deploy theme
    step_info "Setting up Eva Plymouth theme..."
    sudo mkdir -p /usr/share/plymouth/themes/eva

    # If existing theme assets exist in packages/ or themes/
    if [[ -d "${script_root}/themes/plymouth/eva" ]]; then
        sudo cp -r "${script_root}/themes/plymouth/eva"/* /usr/share/plymouth/themes/eva/
    elif [[ -d /usr/share/plymouth/themes/astra ]]; then
        # Use existing verified two-step splash
        sudo cp -r /usr/share/plymouth/themes/astra/* /usr/share/plymouth/themes/eva/
        sudo sed -i 's|Name=.*|Name=Eva Linux|g' /usr/share/plymouth/themes/eva/*.plymouth 2>/dev/null || true
        sudo sed -i 's|ImageDir=.*|ImageDir=/usr/share/plymouth/themes/eva|g' /usr/share/plymouth/themes/eva/*.plymouth 2>/dev/null || true
    fi

    # Set as default theme if directory exists
    if [[ -d /usr/share/plymouth/themes/eva ]]; then
        sudo plymouth-set-default-theme eva 2>/dev/null || true
        step_success "Plymouth default theme set to 'eva'"
    fi
}
