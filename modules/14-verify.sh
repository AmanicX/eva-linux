#!/usr/bin/env bash
# ==============================================================================
#  [14] Post-Installation Validation & Summary
# ==============================================================================

set -Eeuo pipefail

run_verify() {
    printf "\n${C_CRIMSON}${C_BOLD}✦ Eva Linux v2.1 — Installation Verification${C_RESET}\n"
    printf "${C_MUTED}%s${C_RESET}\n\n" "═════════════════════════════════════════════════════════════════"

    local passed=0 failed=0

    check_item() {
        local name="$1"
        shift
        if "$@" >/dev/null 2>&1; then
            printf "  ${C_GREEN}✓${C_RESET} %-40s [OK]\n" "${name}"
            passed=$((passed + 1))
        else
            printf "  ${C_YELLOW}⚠${C_RESET} %-40s [CHECK]\n" "${name}"
            failed=$((failed + 1))
        fi
    }

    check_item "Niri Compositor" command -v niri
    check_item "Niri Configuration Syntax" niri validate -c "${HOME}/.config/niri/config.kdl"
    check_item "Noctalia 5 Shell" command -v noctalia
    check_item "Kitty Terminal" command -v kitty
    check_item "Neovim IDE" command -v nvim
    if command -v qs >/dev/null 2>&1; then
        check_item "Quickshell Toolkit" command -v qs
    else
        check_item "Quickshell Toolkit" command -v quickshell
    fi
    check_item "Keybinds Cheatsheet Overlay" test -f "${HOME}/.config/quickshell/keybinds/shell.qml"
    check_item "Keybinds Database" test -f "${HOME}/.config/quickshell/keybinds/keybinds.json"
    check_item "Keybinds Manager CLI" command -v eva-keybinds-manager
    check_item "Restoration CLI" command -v eva-restore
    check_item "Default Browser CLI" command -v eva-default-browser
    check_item "Wallpaper Synchronizer CLI" command -v eva-wallpaper-sync
    check_item "Wallpaper Installation Helper" test -x /usr/local/libexec/eva-wallpaper-install
    check_item "Default Desktop Wallpaper" test -f "${HOME}/Pictures/Wallpapers/eva-crimson-temple.jpg"
    check_item "PipeWire Audio Stack" command -v pipewire
    if [[ "${SDDM_CONFIGURED:-0}" == "1" ]]; then
        check_item "SilentSDDM Greeter Preset" test -f /usr/share/sddm/themes/silent/configs/eva.conf
    fi
    if [[ "${GRUB_CONFIGURED:-0}" == "1" ]]; then
        check_item "HyperFluent GRUB Theme" test -f /boot/grub/themes/hyperfluent/theme.txt
    fi

    printf "\n${C_BOLD}Verification Results:${C_RESET} ${C_GREEN}%d checks passed${C_RESET}, ${C_YELLOW}%d checks to review${C_RESET}\n" "${passed}" "${failed}"
    if (( failed > 0 )); then
        printf "\n${C_YELLOW}${C_BOLD}Installation needs attention. Review the failed checks above.${C_RESET}\n"
        printf "Log file: %s\n" "${LOG_FILE}"
        return 1
    fi
    printf "\n${C_GREEN}${C_BOLD}✦ Installation Completed Successfully!${C_RESET}\n"
    printf "${C_MUTED}Log file: %s${C_RESET}\n\n" "${LOG_FILE}"
    printf "Next Steps:\n"
    printf "  1. Log into your Niri session from SDDM.\n"
    printf "  2. Press ${C_BOLD}Super + Shift + /${C_RESET} at any time to open the interactive Keybind Cheatsheet.\n"
    printf "  3. Press ${C_BOLD}Super + Alt + Space${C_RESET} to open Noctalia's wallpaper picker (auto-syncs to SDDM & GRUB).\n"
    printf "  4. Press ${C_BOLD}Super + Enter${C_RESET} to open Kitty terminal.\n"
    printf "  5. In case you need to restore previous configs: run ${C_BOLD}eva-restore${C_RESET}.\n\n"
}
