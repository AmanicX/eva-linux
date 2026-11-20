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
    sudo ln -sf "/usr/local/bin/eva-wallpaper-sync" "/usr/bin/eva-wallpaper-sync"

    # 3. Configure Sudoers Drop-in for Passwordless Theme Sync
    step_info "Configuring permission rule for boot/greeter wallpaper sync..."
    cat << 'SUDO_RULE' | sudo tee /etc/sudoers.d/eva-wallpaper-sync >/dev/null
# Allow eva-wallpaper-sync helper to update theme backgrounds safely without full root shell
ALL ALL = (root) NOPASSWD: /usr/bin/cp /tmp/eva-grub-bg.png /boot/grub/themes/hyperfluent/background.png, /usr/bin/cp /tmp/eva-grub-bg.png /boot/grub/themes/eva/background.png, /usr/bin/cp * /usr/share/sddm/themes/silent/backgrounds/eva-wallpaper.jpg, /usr/bin/cp /tmp/eva-sddm.conf /usr/share/sddm/themes/silent/configs/eva.conf
SUDO_RULE
    sudo chmod 440 /etc/sudoers.d/eva-wallpaper-sync

    # 4. Deploy Systemd User Service for Background Watcher
    step_info "Setting up eva-wallpaper-sync background user service..."
    mkdir -p "${HOME}/.config/systemd/user"
    cat << 'UNIT' > "${HOME}/.config/systemd/user/eva-wallpaper-sync.service"
[Unit]
Description=Eva Linux Noctalia Wallpaper Synchronizer
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/local/bin/eva-wallpaper-sync --watch
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT

    systemctl --user daemon-reload 2>/dev/null || true
    systemctl --user enable --now eva-wallpaper-sync.service 2>/dev/null || true

    # 5. Run Initial Synchronization
    step_info "Running initial wallpaper synchronization..."
    /usr/local/bin/eva-wallpaper-sync "${default_wp}" || true

    step_success "Wallpaper management & synchronization active"
}
