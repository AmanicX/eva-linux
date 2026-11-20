#!/usr/bin/env bash
# ==============================================================================
#  [06] Desktop Configuration Deployment (Niri, Noctalia 5, Kitty, Neovim, GTK)
# ==============================================================================

set -Eeuo pipefail

run_desktop_config() {
    step_header 7 14 "Desktop Configurations Deployment"

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"
    local cfg_src="${script_root}/configs"

    # 1. Niri Configuration
    step_info "Deploying Niri compositor configuration..."
    mkdir -p "${HOME}/.config/niri"
    cp "${cfg_src}/niri"/*.kdl "${HOME}/.config/niri/"
    # Validate Niri configuration immediately
    if command -v niri >/dev/null 2>&1; then
        if niri validate -c "${HOME}/.config/niri/config.kdl" >/dev/null 2>&1; then
            step_success "Niri configuration validated successfully"
        else
            step_error "Niri configuration is invalid. Restore your backup before starting a new session."
            return 1
        fi
    fi

    # 2. Noctalia 5 Configuration
    step_info "Deploying Noctalia 5 shell configuration & state..."
    mkdir -p "${HOME}/.config/noctalia" "${HOME}/.local/state/noctalia"
    cp -r "${cfg_src}/noctalia"/noctalia-integration.toml "${HOME}/.config/noctalia/" 2>/dev/null || true
    if [[ ! -f "${HOME}/.local/state/noctalia/settings.toml" ]] || ask_confirm "Apply Eva Linux default Noctalia state settings?" "y"; then
        python3 - "${cfg_src}/noctalia/settings.toml" "${HOME}/.local/state/noctalia/settings.toml" <<'PY'
import json
import os
from pathlib import Path
import sys

content = Path(sys.argv[1]).read_text(encoding="utf-8")
for value in ("~/Pictures/Wallpapers", "~/Pictures/Wallpapers/eva-crimson-temple.jpg"):
    content = content.replace(json.dumps(value), json.dumps(os.path.expanduser(value)))
Path(sys.argv[2]).write_text(content, encoding="utf-8")
PY
        step_success "Noctalia 5 settings deployed"
    fi

    # 3. Kitty Terminal Configuration
    step_info "Deploying Kitty terminal configuration..."
    mkdir -p "${HOME}/.config/kitty/themes"
    cp -r "${cfg_src}/kitty"/* "${HOME}/.config/kitty/"
    step_success "Kitty configuration deployed"

    # 4. Neovim & LazyVim Configuration
    step_info "Deploying Neovim & LazyVim configuration..."
    mkdir -p "${HOME}/.config/nvim"
    cp -r "${cfg_src}/nvim"/* "${HOME}/.config/nvim/"
    step_success "Neovim IDE configuration deployed"

    # 5. GTK, Cursor & Appearance
    step_info "Configuring GTK3, GTK4 and XSettings..."
    mkdir -p "${HOME}/.config/gtk-3.0" "${HOME}/.config/gtk-4.0" "${HOME}/.config/xsettingsd"
    [[ -f "${cfg_src}/gtk/gtk3-settings.ini" ]] && cp "${cfg_src}/gtk/gtk3-settings.ini" "${HOME}/.config/gtk-3.0/settings.ini"
    [[ -f "${cfg_src}/gtk/gtk4-settings.ini" ]] && cp "${cfg_src}/gtk/gtk4-settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"
    [[ -f "${cfg_src}/gtk/xsettingsd.conf" ]] && cp "${cfg_src}/gtk/xsettingsd.conf" "${HOME}/.config/xsettingsd/xsettingsd.conf"
    step_success "GTK appearance deployed"

    # 6. Fastfetch
    if [[ -d "${cfg_src}/fastfetch" ]]; then
        mkdir -p "${HOME}/.config/fastfetch"
        cp -r "${cfg_src}/fastfetch"/* "${HOME}/.config/fastfetch/" 2>/dev/null || true
    fi

    # 7. User Dirs (XDG)
    step_info "Ensuring standard user directories exist..."
    xdg-user-dirs-update 2>/dev/null || true
    mkdir -p "${HOME}/Pictures/Screenshots" "${HOME}/Pictures/Wallpapers"

    step_success "Desktop configurations deployed successfully"
}
