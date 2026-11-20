#!/usr/bin/env bash
# ==============================================================================
#  [01] Configuration Backups & Manifest
# ==============================================================================

set -Eeuo pipefail

run_backup() {
    step_header 2 14 "Configuration Backup"

    if [[ "${OPT_SKIP_BACKUP:-0}" == "1" ]]; then
        step_info "Backup skipped via --skip-backup flag"
        return 0
    fi

    if ! ask_confirm "Do you want to create a timestamped backup of your desktop configurations?" "y"; then
        step_warn "Configuration backup declined. Proceeding with safe-install protections."
        return 0
    fi

    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_dir="${HOME}/eva_backups/backup_${timestamp}"
    mkdir -p "${backup_dir}/config" "${backup_dir}/state" "${backup_dir}/system"

    local manifest="${backup_dir}/manifest.txt"
    {
        echo "# Eva Linux v2 Backup Manifest"
        echo "# Created: $(date)"
        echo "# Target: ${backup_dir}"
        echo "# Restore command: eva-restore ${backup_dir}"
        echo ""
    } > "${manifest}"

    step_info "Backing up user configurations to ${backup_dir}..."

    # List of configuration items to preserve
    local configs=(
        "niri"
        "noctalia"
        "kitty"
        "nvim"
        "quickshell"
        "gtk-3.0"
        "gtk-4.0"
        "xsettingsd"
        "fastfetch"
    )

    for c in "${configs[@]}"; do
        if [[ -d "${HOME}/.config/${c}" ]]; then
            cp -r "${HOME}/.config/${c}" "${backup_dir}/config/"
            echo "config/${c}" >> "${manifest}"
            step_info "  Preserved ~/.config/${c}"
        fi
    done

    # Noctalia local state
    if [[ -d "${HOME}/.local/state/noctalia" ]]; then
        cp -r "${HOME}/.local/state/noctalia" "${backup_dir}/state/"
        echo "state/noctalia" >> "${manifest}"
        step_info "  Preserved ~/.local/state/noctalia"
    fi

    # System configs (SDDM, GRUB) if readable
    if [[ -r /etc/sddm.conf ]]; then
        cp /etc/sddm.conf "${backup_dir}/system/sddm.conf" 2>/dev/null || true
        echo "system/sddm.conf" >> "${manifest}"
    fi
    if [[ -r /etc/default/grub ]]; then
        cp /etc/default/grub "${backup_dir}/system/grub.default" 2>/dev/null || true
        echo "system/grub.default" >> "${manifest}"
    fi

    step_success "Backup completed successfully (${backup_dir})"
    step_info "To restore this backup at any time, run: eva-restore"
}
