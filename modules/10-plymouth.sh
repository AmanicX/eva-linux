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

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"
    local theme_src="${script_root}/themes/plymouth/eva"
    if [[ ! -f "${theme_src}/eva.plymouth" ]]; then
        step_info "Skipping Plymouth: no Eva theme assets are shipped. Existing boot splash left unchanged."
        return 0
    fi

    if ! ask_confirm "Configure the Eva Plymouth theme and rebuild the initramfs?" "n"; then
        step_info "Plymouth setup skipped by user."
        return 0
    fi

    sudo mkdir -p /usr/share/plymouth/themes/eva
    sudo cp -r "${theme_src}"/* /usr/share/plymouth/themes/eva/
    if ! sudo plymouth-set-default-theme -R eva; then
        step_error "Plymouth theme activation failed."
        return 1
    fi
    step_success "Plymouth default theme set to 'eva'"
}
