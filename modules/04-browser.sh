#!/usr/bin/env bash
# ==============================================================================
#  [04] Browser Selection & Configuration
# ==============================================================================

set -Eeuo pipefail

run_browser() {
    step_header 5 14 "Web Browser Selection"

    # Detect existing browsers
    local installed_browsers=()
    command -v firefox >/dev/null 2>&1 && installed_browsers+=("firefox")
    command -v chromium >/dev/null 2>&1 && installed_browsers+=("chromium")
    command -v google-chrome-stable >/dev/null 2>&1 && installed_browsers+=("google-chrome-stable")
    command -v brave >/dev/null 2>&1 && installed_browsers+=("brave")
    command -v vivaldi >/dev/null 2>&1 && installed_browsers+=("vivaldi")
    command -v zen-browser >/dev/null 2>&1 && installed_browsers+=("zen-browser")
    command -v helium >/dev/null 2>&1 && installed_browsers+=("helium")
    command -v opera >/dev/null 2>&1 && installed_browsers+=("opera")

    if [[ ${#installed_browsers[@]} -gt 0 ]]; then
        step_info "Detected installed browser(s): ${installed_browsers[*]}"
        if ! ask_confirm "Do you wish to install an additional web browser?" "n"; then
            step_success "Using existing browser: ${installed_browsers[0]}"
            return 0
        fi
    fi

    printf "  Select a web browser to install:\n"
    printf "    1) Firefox (Official Arch package, privacy-focused, recommended)\n"
    printf "    2) Zen Browser (Modern Firefox fork optimized for tiling & tabs)\n"
    printf "    3) Brave Browser (Chromium-based with built-in adblocking)\n"
    printf "    4) Chromium (Open-source Chromium base)\n"
    printf "    5) Google Chrome (Proprietary Google browser)\n"
    printf "    6) Vivaldi (Highly customizable power-user browser)\n"
    printf "    7) Skip browser installation\n"

    local choice="1"
    if [[ "${OPT_NON_INTERACTIVE:-0}" != "1" ]]; then
        printf "  Selection [1-7, default 1]: "
        read -r choice </dev/tty || choice="1"
    fi

    case "${choice}" in
        1)
            step_info "Installing Firefox via pacman..."
            sudo pacman -S --needed --noconfirm firefox
            xdg-settings set default-web-browser firefox.desktop 2>/dev/null || true
            step_success "Firefox installed and set as default"
            ;;
        2)
            step_info "Installing Zen Browser from AUR..."
            "${AUR_HELPER}" -S --needed --noconfirm zen-browser-bin
            xdg-settings set default-web-browser zen-browser.desktop 2>/dev/null || true
            step_success "Zen Browser installed"
            ;;
        3)
            step_info "Installing Brave Browser from AUR..."
            "${AUR_HELPER}" -S --needed --noconfirm brave-bin
            xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || true
            step_success "Brave Browser installed"
            ;;
        4)
            step_info "Installing Chromium via pacman..."
            sudo pacman -S --needed --noconfirm chromium
            xdg-settings set default-web-browser chromium.desktop 2>/dev/null || true
            step_success "Chromium installed"
            ;;
        5)
            step_info "Installing Google Chrome from AUR..."
            "${AUR_HELPER}" -S --needed --noconfirm google-chrome
            xdg-settings set default-web-browser google-chrome.desktop 2>/dev/null || true
            step_success "Google Chrome installed"
            ;;
        6)
            step_info "Installing Vivaldi from AUR..."
            "${AUR_HELPER}" -S --needed --noconfirm vivaldi
            xdg-settings set default-web-browser vivaldi-stable.desktop 2>/dev/null || true
            step_success "Vivaldi installed"
            ;;
        *)
            step_info "Browser installation skipped."
            ;;
    esac
}
