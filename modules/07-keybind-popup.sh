#!/usr/bin/env bash
# ==============================================================================
#  [07] Keybind Cheatsheet Popup & Quickshell Daemon
# ==============================================================================

set -Eeuo pipefail

run_keybind_popup() {
    step_header 8 14 "Keybind Cheatsheet Popup Setup"

    local script_root
    script_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd -P)"

    # 1. Install Executables to /usr/local/bin
    step_info "Installing keybind management binaries to /usr/local/bin..."
    sudo install -m 755 "${script_root}/bin/eva-keybinds-manager" "/usr/local/bin/eva-keybinds-manager"
    sudo install -m 755 "${script_root}/bin/eva-keybinds-start" "/usr/local/bin/eva-keybinds-start"
    sudo install -m 755 "${script_root}/bin/eva-keybinds-toggle" "/usr/local/bin/eva-keybinds-toggle"
    sudo install -m 755 "${script_root}/bin/eva-restore" "/usr/local/bin/eva-restore"
    sudo install -m 755 "${script_root}/bin/eva-default-browser" "/usr/local/bin/eva-default-browser"

    # Also install to /usr/bin for universal access
    sudo ln -sf "/usr/local/bin/eva-keybinds-start" "/usr/bin/eva-keybinds-start"
    sudo ln -sf "/usr/local/bin/eva-keybinds-toggle" "/usr/bin/eva-keybinds-toggle"

    # 2. Shared Assets & Generator Location
    sudo mkdir -p "/usr/share/eva/keybinds" "/usr/share/astra/keybinds"
    sudo ln -sf "/usr/local/bin/eva-keybinds-manager" "/usr/share/eva/keybinds/gen-keybinds.py"

    # 3. Backward Compatibility Symlinks for Existing Shortcuts
    sudo ln -sf "/usr/local/bin/eva-keybinds-start" "/usr/local/bin/astra-keybinds-start"
    sudo ln -sf "/usr/local/bin/eva-keybinds-toggle" "/usr/local/bin/astra-keybinds-toggle"
    sudo ln -sf "/usr/local/bin/eva-keybinds-start" "/usr/bin/astra-keybinds-start"
    sudo ln -sf "/usr/local/bin/eva-keybinds-toggle" "/usr/bin/astra-keybinds-toggle"
    sudo ln -sf "/usr/local/bin/eva-keybinds-manager" "/usr/share/astra/keybinds/gen-keybinds.py"

    # Ensure python3 has tomlkit/json requirements
    sudo pacman -S --needed --noconfirm python-json5 2>/dev/null || true

    # 4. Deploy Quickshell Keybinds QML Overlay
    step_info "Deploying Quickshell QML overlay to ~/.config/quickshell/keybinds/..."
    mkdir -p "${HOME}/.config/quickshell/keybinds"
    cp -r "${script_root}/configs/quickshell/keybinds"/* "${HOME}/.config/quickshell/keybinds/"

    # 5. Generate Initial keybinds.json
    step_info "Generating keybinds.json from active keybinds.kdl..."
    if "/usr/local/bin/eva-keybinds-manager"; then
        step_success "Keybinds database generated successfully"
    else
        step_warn "Initial keybinds generation reported a warning, but setup will continue."
    fi

    # 6. Verify Niri Binding
    if grep -q "eva-keybinds-toggle" "${HOME}/.config/niri/keybinds.kdl" || \
       grep -q "astra-keybinds-toggle" "${HOME}/.config/niri/keybinds.kdl"; then
        step_success "Niri overlay shortcut (Super + Shift + /) is configured"
    fi

    step_success "Keybind cheatsheet popup installed and verified"
}
