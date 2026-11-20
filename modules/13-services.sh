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

    if [[ "${DETECTED_DM}" == "sddm" || -f /usr/bin/sddm ]]; then
        system_services+=("sddm.service")
    fi

    step_info "Enabling core system services..."
    for s in "${system_services[@]}"; do
        if systemctl list-unit-files "${s}" >/dev/null 2>&1; then
            sudo systemctl enable "${s}" 2>/dev/null || true
            step_info "  Enabled ${s}"
        fi
    done

    # 2. PipeWire Audio & User Stack
    step_info "Configuring PipeWire user services..."
    systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

    step_success "System and user services configured"
}
