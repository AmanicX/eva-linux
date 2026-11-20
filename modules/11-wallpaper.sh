#!/usr/bin/env bash
# ==============================================================================
#  [11] Wallpaper Management & Noctalia Synchronization
# ==============================================================================

set -Eeuo pipefail

run_wallpaper() {
    step_header 12 14 "Wallpaper Management & Synchronization"

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"

    # 1. Deploy Wallpapers
    step_info "Deploying wallpapers to ~/Pictures/Wallpapers/..."
    mkdir -p "${HOME}/Pictures/Wallpapers"
    cp -r "${script_root}/assets/wallpapers"/* "${HOME}/Pictures/Wallpapers/" 2>/dev/null || true

    local default_wp="${HOME}/Pictures/Wallpapers/eva-crimson-temple.jpg"
    if [[ ! -f "${default_wp}" && -f "${script_root}/assets/wallpapers/eva-crimson-temple.jpg" ]]; then
        cp "${script_root}/assets/wallpapers/eva-crimson-temple.jpg" "${default_wp}"
    fi

    # 2. Install Synchronization Binary
    step_info "Installing eva-wallpaper-sync to /usr/local/bin..."
    sudo install -m 755 "${script_root}/bin/eva-wallpaper-sync" "/usr/local/bin/eva-wallpaper-sync"
    sudo install -d -m 755 /usr/local/libexec
    sudo install -o root -g root -m 755 "${script_root}/bin/eva-wallpaper-install" /usr/local/libexec/eva-wallpaper-install

    # Replace the legacy broad cp grant, including on upgrades.
    sudo rm -f -- /etc/sudoers.d/eva-wallpaper-sync
    local sync_user rule_file
    sync_user="$(id -un)"
    if [[ ! "${sync_user}" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ ]]; then
        step_error "Cannot safely create a sudoers rule for this username."
        return 1
    fi
    rule_file="$(mktemp)"
    printf '%s ALL=(root) NOPASSWD: /usr/local/libexec/eva-wallpaper-install sddm, /usr/local/libexec/eva-wallpaper-install grub\n' \
        "${sync_user}" > "${rule_file}"
    if ! sudo visudo -cf "${rule_file}"; then
        rm -f -- "${rule_file}"
        step_error "Wallpaper permission rule failed validation."
        return 1
    fi
    sudo install -o root -g root -m 440 "${rule_file}" "/etc/sudoers.d/eva-wallpaper-${sync_user}"
    rm -f -- "${rule_file}"

    # 4. Deploy Systemd User Service for Background Watcher
    step_info "Setting up eva-wallpaper-sync background user service..."
    mkdir -p "${HOME}/.config/systemd/user"
    cat << 'UNIT' > "${HOME}/.config/systemd/user/eva-wallpaper-sync.service"
[Unit]
Description=Eva Linux Noctalia Wallpaper Synchronizer
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/eva-wallpaper-sync --watch
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
UNIT

    if systemctl --user daemon-reload && systemctl --user enable eva-wallpaper-sync.service; then
        if systemctl --user is-active --quiet graphical-session.target; then
            systemctl --user restart eva-wallpaper-sync.service
        fi
    else
        step_warn "Wallpaper watcher could not be enabled; retry in your graphical session."
    fi

    # 5. Run Initial Synchronization
    step_info "Running initial wallpaper synchronization..."
    if ! /usr/local/bin/eva-wallpaper-sync "${default_wp}"; then
        step_warn "Initial wallpaper sync failed; check the permission rule and installed themes."
        return 1
    fi

    step_success "Wallpaper management & synchronization active"
}
