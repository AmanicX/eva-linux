#!/usr/bin/env bash
# ==============================================================================
#  [09] HyperFluent GRUB Bootloader Theme Setup
# ==============================================================================

set -Eeuo pipefail

run_grub() {
    step_header 10 14 "HyperFluent GRUB Theme Setup"
    export GRUB_CONFIGURED=0

    if [[ "${DETECTED_BOOTLOADER}" != "grub" ]]; then
        step_info "GRUB bootloader not detected on this system. Skipping GRUB theming."
        return 0
    fi

    if ! ask_confirm "Do you want to install the upstream HyperFluent GRUB theme?" "y"; then
        step_info "HyperFluent GRUB theming skipped by user."
        return 0
    fi

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"
    local hyperfluent_src="${script_root}/themes/grub/hyperfluent/arch"

    if [[ ! -d "${hyperfluent_src}" ]]; then
        step_warn "HyperFluent Arch theme directory not found. Skipping."
        return 0
    fi

    # 1. Back up /etc/default/grub
    if [[ ! -f /etc/default/grub ]]; then
        step_warn "GRUB defaults not found. Leaving bootloader configuration unchanged."
        return 0
    fi
    local defaults_backup="/etc/default/grub.bak-eva-$(date +%Y%m%d%H%M%S)"
    sudo cp /etc/default/grub "${defaults_backup}"

    # 2. Deploy Theme to /boot/grub/themes/hyperfluent
    step_info "Deploying HyperFluent theme to /boot/grub/themes/hyperfluent/..."
    sudo mkdir -p /boot/grub/themes/hyperfluent
    sudo cp -r "${hyperfluent_src}"/* /boot/grub/themes/hyperfluent/

    # 3. Synchronize Initial Wallpaper as background.png
    step_info "Generating boot-compatible background.png..."
    local tmp_bg
    tmp_bg="$(mktemp --suffix=.png)"
    if ! python3 - "${script_root}/assets/wallpapers/eva-crimson-temple.jpg" "${tmp_bg}" <<'PY'
import sys
from PIL import Image
with Image.open(sys.argv[1]) as image:
    image = image.convert("RGB")
    image.thumbnail((3840, 2160))
    image.save(sys.argv[2], "PNG")
PY
    then
        rm -f -- "${tmp_bg}"
        step_error "Failed to convert the GRUB wallpaper. Check python-pillow."
        return 1
    fi

    if [[ -f "${tmp_bg}" ]]; then
        sudo cp "${tmp_bg}" /boot/grub/themes/hyperfluent/background.png
        rm -f "${tmp_bg}"
    fi

    # 4. Configure /etc/default/grub
    step_info "Configuring GRUB_THEME in /etc/default/grub..."
    if grep -q "^GRUB_THEME=" /etc/default/grub; then
        sudo sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/hyperfluent/theme.txt"|' /etc/default/grub
    else
        echo 'GRUB_THEME="/boot/grub/themes/hyperfluent/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
    fi

    # 5. Safe GRUB Config Regeneration (Only done on initial install)
    step_info "Generating grub.cfg..."
    local staged_config
    staged_config="$(sudo mktemp /boot/grub/grub.cfg.eva.XXXXXXXX)"
    if sudo grub-mkconfig -o "${staged_config}"; then
        sudo mv -f -- "${staged_config}" /boot/grub/grub.cfg
        export GRUB_CONFIGURED=1
        step_success "HyperFluent GRUB theme installed successfully"
        step_info "Note: Future wallpaper changes update background.png directly without requiring grub-mkconfig."
    else
        step_error "Failed to generate GRUB config. Restoring previous /etc/default/grub..."
        sudo cp -- "${defaults_backup}" /etc/default/grub
        sudo rm -f -- "${staged_config}"
        return 1
    fi
}
