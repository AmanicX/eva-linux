#!/usr/bin/env bash
# ==============================================================================
#  [03] AUR Helper Management (yay / paru)
# ==============================================================================

set -Eeuo pipefail

is_helper_functional() {
    local helper="$1"
    command -v "${helper}" >/dev/null 2>&1 && "${helper}" --version >/dev/null 2>&1
}

run_aur_helper() {
    step_header 4 14 "AUR Helper Selection & Verification"

    AUR_HELPER=""

    # 1. Detect Existing Functional Helpers
    if is_helper_functional yay; then
        AUR_HELPER="yay"
        step_success "Found active and functional AUR helper: yay ($(yay --version | head -n1))"
    elif is_helper_functional paru; then
        AUR_HELPER="paru"
        step_success "Found active and functional AUR helper: paru ($(paru --version | head -n1))"
    fi

    # 2. If neither is installed, prompt user choice
    if [[ -z "${AUR_HELPER}" ]]; then
        step_info "No functioning AUR helper detected."
        printf "  Choose your preferred AUR helper:\n"
        printf "    1) yay (Recommended - fast, stable, widely supported)\n"
        printf "    2) paru (Rust-based pacman wrapper with rich interactive search)\n"
        
        local choice="1"
        if [[ "${OPT_NON_INTERACTIVE:-0}" != "1" ]]; then
            printf "  Selection [1/2, default 1]: "
            read -r choice </dev/tty || choice="1"
        fi

        local target_helper="yay"
        [[ "${choice}" == "2" ]] && target_helper="paru"

        step_info "Installing ${target_helper}-bin from AUR..."
        local build_dir="/tmp/${target_helper}-bin-build"
        rm -rf "${build_dir}"

        if git clone --depth 1 "https://aur.archlinux.org/${target_helper}-bin.git" "${build_dir}"; then
            (
                cd "${build_dir}"
                makepkg -si --noconfirm
            )
            rm -rf "${build_dir}"
            AUR_HELPER="${target_helper}"
            step_success "${target_helper} installed successfully"
        else
            step_error "Failed to clone ${target_helper}-bin repository from AUR."
            exit 1
        fi
    fi

    # 3. Final verification
    if ! is_helper_functional "${AUR_HELPER}"; then
        step_error "AUR helper '${AUR_HELPER}' failed verification. Please check your pacman/libalpm versions."
        exit 1
    fi

    export AUR_HELPER
    step_success "AUR helper ready: ${AUR_HELPER}"
}
