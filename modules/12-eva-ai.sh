#!/usr/bin/env bash
# ==============================================================================
#  [12] Optional Eva Advanced AI Chatbot Integration
# ==============================================================================

set -Eeuo pipefail

run_eva_ai() {
    step_header 13 14 "Optional Eva Advanced AI Chatbot"

    if ! ask_confirm "Do you want to install Eva Advanced AI Chatbot studio?" "y"; then
        step_info "Eva AI Chatbot installation declined by user. Skipping."
        return 0
    fi

    step_info "Checking Eva AI Chatbot installation status..."

    # Check if already installed in system or user space
    if command -v eva >/dev/null 2>&1; then
        step_success "Eva binary already found in PATH: $(command -v eva)"
    elif [[ -x "${HOME}/Applications/eva/eva" ]]; then
        step_info "Found Eva local installation in ~/Applications/eva/eva"
        sudo ln -sf "${HOME}/Applications/eva/eva" "/usr/local/bin/eva"
        step_success "Created /usr/local/bin/eva symlink"
    elif [[ -f "${HOME}/Applications/Eva.AppImage" ]]; then
        step_info "Found Eva.AppImage in ~/Applications"
        chmod +x "${HOME}/Applications/Eva.AppImage"
        sudo ln -sf "${HOME}/Applications/Eva.AppImage" "/usr/local/bin/eva"
        step_success "Configured Eva.AppImage as /usr/local/bin/eva"
    elif [[ -d "${HOME}/eva-bin" && -f "${HOME}/eva-bin/PKGBUILD" ]]; then
        step_info "Building and installing eva-bin from local package source..."
        (
            cd "${HOME}/eva-bin"
            makepkg -si --noconfirm || true
        )
    else
        step_info "Downloading Eva AppImage release from upstream..."
        mkdir -p "${HOME}/Applications"
        local appimage_url="https://github.com/AmanicX/eva/releases/latest/download/Eva.AppImage"
        if curl -fsSL -L -o "${HOME}/Applications/Eva.AppImage" "${appimage_url}"; then
            chmod +x "${HOME}/Applications/Eva.AppImage"
            sudo ln -sf "${HOME}/Applications/Eva.AppImage" "/usr/local/bin/eva"
            step_success "Eva AppImage downloaded and configured"
        else
            step_warn "Could not download Eva release directly. Skipping optional component."
            return 0
        fi
    fi

    # Ensure desktop entry is deployed
    mkdir -p "${HOME}/.local/share/applications"
    cat << 'DESKTOP' > "${HOME}/.local/share/applications/eva.desktop"
[Desktop Entry]
Type=Application
Name=Eva
GenericName=Eva - Advanced AI Chatbot
Comment=Multi-theme, memory-aware AI character and world chat studio
Exec=eva %U
Icon=eva
Terminal=false
Categories=Utility;ArtificialIntelligence;Development;AudioVideo;
StartupWMClass=Eva
MimeType=x-scheme-handler/eva;
Keywords=eva;ai;chat;llm;character;world;gemma;ollama;
DESKTOP

    # Deploy icon if present
    if [[ -f "${HOME}/eva-website/public/favicon.svg" ]]; then
        mkdir -p "${HOME}/.local/share/icons/hicolor/scalable/apps"
        cp "${HOME}/eva-website/public/favicon.svg" "${HOME}/.local/share/icons/hicolor/scalable/apps/eva.svg"
    fi

    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
    step_success "Eva Advanced AI Chatbot configured successfully"
}
