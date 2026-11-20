#!/usr/bin/env bash
# ==============================================================================
#  [08] SilentSDDM Login Theme Installation & Configuration
# ==============================================================================

set -Eeuo pipefail

configure_sddm_preset() {
    local theme_dir="$1"
    sudo cp -- "${theme_dir}/configs/default.conf" "${theme_dir}/configs/eva.conf"
    sudo sed -i 's|^background[[:space:]]*=.*|background = "eva-wallpaper.jpg"|' "${theme_dir}/configs/eva.conf"
    sudo sed -i 's|^ConfigFile=.*|ConfigFile=configs/eva.conf|' "${theme_dir}/metadata.desktop"
}

run_sddm() {
    step_header 9 14 "SilentSDDM Display Manager Setup"
    export ENABLE_SDDM=0 SDDM_CONFIGURED=0

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"
    local sddm_theme_src="${script_root}/themes/sddm/silent"

    if [[ "${DETECTED_DM}" != "sddm" ]]; then
        step_warn "Detected display manager: ${DETECTED_DM}"
        if ! ask_confirm "Use SDDM instead of ${DETECTED_DM} at the next boot (without stopping this session)?" "y"; then
            step_info "SDDM configuration skipped."
            return 0
        fi
    fi
    export ENABLE_SDDM=1

    if ! ask_confirm "Install and configure upstream SilentSDDM theme?" "y"; then
        step_info "SilentSDDM theme installation skipped by user."
        return 0
    fi

    # 1. Install Upstream SilentSDDM to /usr/share/sddm/themes/silent
    step_info "Installing upstream SilentSDDM theme..."
    sudo mkdir -p /usr/share/sddm/themes/silent
    sudo cp -r "${sddm_theme_src}"/* /usr/share/sddm/themes/silent/

    # 2. Deploy Eva Wallpaper to Theme Backgrounds
    step_info "Configuring default theme wallpaper..."
    sudo mkdir -p /usr/share/sddm/themes/silent/backgrounds
    sudo cp "${script_root}/assets/wallpapers/eva-crimson-temple.jpg" /usr/share/sddm/themes/silent/backgrounds/eva-wallpaper.jpg

    # 3. Create clean eva preset pointing to eva-wallpaper.jpg
    configure_sddm_preset /usr/share/sddm/themes/silent

    # 4. Configure SDDM
    step_info "Writing SDDM configuration..."
    sudo mkdir -p /etc/sddm.conf.d

    cat << 'CONF' | sudo tee /etc/sddm.conf.d/eva.conf >/dev/null
[General]
DisplayServer=x11
Numlock=on
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent
CursorTheme=Adwaita
CursorSize=24
Font=Adwaita Sans
EnableAvatars=true

[Users]
RememberLastUser=true
RememberLastSession=true

[Autologin]
Session=niri.desktop
CONF

    export SDDM_CONFIGURED=1
    step_success "SilentSDDM theme configured with Eva Linux wallpaper"
}
