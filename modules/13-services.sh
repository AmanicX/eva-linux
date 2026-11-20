#!/usr/bin/env bash
# ==============================================================================
#  [13] System & User Services Enablement
# ==============================================================================

set -Eeuo pipefail

run_services() {
    step_header 14 14 "System Services Enablement"

    # 1. System Services
    local system_services=(
        "NetworkManager.service"
        "bluetooth.service"
        "power-profiles-daemon.service"
    )

    step_info "Enabling core system services..."
    for s in "${system_services[@]}"; do
        if systemctl list-unit-files "${s}" >/dev/null 2>&1; then
            if sudo systemctl enable "${s}"; then
                step_info "  Enabled ${s}"
            else
                step_error "Could not enable ${s}."
                return 1
            fi
        fi
    done

    # Only switch managers after explicit consent in run_sddm. Do not stop the
    # currently running manager: that would terminate the user's session.
    if [[ "${ENABLE_SDDM:-0}" == "1" ]]; then
        local previous_dm=""
        case "${DETECTED_DM:-none}" in
            gdm|lightdm)
                previous_dm="${DETECTED_DM}.service"
                sudo systemctl disable "${previous_dm}"
                ;;
        esac
        if ! sudo systemctl enable sddm.service; then
            if [[ -n "${previous_dm}" ]]; then
                sudo systemctl enable "${previous_dm}"
            fi
            step_error "Could not enable SDDM; previous display manager restored."
            return 1
        fi
    fi

    # 2. PipeWire Audio & User Stack
    step_info "Configuring PipeWire user services..."
    if ! systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service; then
        step_warn "Audio user services could not be started; retry from your graphical session."
    fi

    step_success "System and user services configured"
}
