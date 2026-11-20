#!/usr/bin/env bash
# ==============================================================================
#  [00] System & Hardware Detection
# ==============================================================================

set -Eeuo pipefail

run_detect() {
    step_header 1 14 "System & Hardware Detection"

    # 1. OS & Distribution Detection
    if [[ ! -f /etc/os-release ]]; then
        step_error "Unable to determine OS: /etc/os-release is missing."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    DETECTED_OS="${NAME:-Linux}"
    DETECTED_ID="${ID:-unknown}"
    DETECTED_ID_LIKE="${ID_LIKE:-}"

    step_info "Operating System: ${DETECTED_OS} (${DETECTED_ID})"

    IS_ARCH_COMPATIBLE=0
    if [[ "${DETECTED_ID}" == "arch" || "${DETECTED_ID_LIKE}" =~ arch|archlinux ]]; then
        IS_ARCH_COMPATIBLE=1
        step_success "Distribution is Arch Linux or compatible rolling release"
    else
        step_warn "Distribution '${DETECTED_ID}' is not an Arch-based system."
        step_warn "Eva Linux v2 primary desktop automation is designed for Arch Linux."
        if ! ask_confirm "Do you wish to continue anyway with best-effort mode?" "n"; then
            step_info "Aborting installation."
            exit 0
        fi
    fi

    # 2. Architecture & Kernel
    ARCH="$(uname -m)"
    KERNEL="$(uname -r)"
    step_info "Architecture: ${ARCH} | Kernel: ${KERNEL}"
    if [[ "${ARCH}" != "x86_64" ]]; then
        step_error "Unsupported architecture: ${ARCH}. Eva Linux requires x86_64."
        exit 1
    fi

    # 3. CPU & Memory Detection
    CPU_MODEL="$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^[ \t]*//' || echo "Unknown CPU")"
    TOTAL_RAM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)"
    step_info "Processor: ${CPU_MODEL}"
    step_info "Memory: ${TOTAL_RAM_MB} MB RAM"

    # 4. GPU Detection
    DETECTED_GPU_VENDOR="unknown"
    DETECTED_GPU_NAME=""
    if command -v lspci >/dev/null 2>&1; then
        VGA_INFO="$(lspci | grep -E "VGA|3D|Display" || true)"
        if echo "${VGA_INFO}" | grep -iq "nvidia"; then
            DETECTED_GPU_VENDOR="nvidia"
        elif echo "${VGA_INFO}" | grep -iq "advanced micro devices\|amd\|ati"; then
            DETECTED_GPU_VENDOR="amd"
        elif echo "${VGA_INFO}" | grep -iq "intel"; then
            DETECTED_GPU_VENDOR="intel"
        elif echo "${VGA_INFO}" | grep -iq "vmware\|virtio\|qemu\|virtualbox"; then
            DETECTED_GPU_VENDOR="vm"
        fi
        DETECTED_GPU_NAME="$(echo "${VGA_INFO}" | head -n1 | cut -d: -f3- | sed 's/^[ \t]*//')"
    fi
    step_info "Graphics: ${DETECTED_GPU_VENDOR^^} (${DETECTED_GPU_NAME:-Generic Display})"

    # 5. Bootloader Detection
    DETECTED_BOOTLOADER="unknown"
    if [[ -d /boot/grub ]]; then
        DETECTED_BOOTLOADER="grub"
    elif [[ -d /boot/loader ]]; then
        DETECTED_BOOTLOADER="systemd-boot"
    fi
    step_info "Bootloader: ${DETECTED_BOOTLOADER}"

    # 6. Display Manager Detection
    DETECTED_DM="none"
    if systemctl is-active --quiet sddm 2>/dev/null || [[ -f /usr/bin/sddm ]]; then
        DETECTED_DM="sddm"
    elif systemctl is-active --quiet gdm 2>/dev/null || [[ -f /usr/bin/gdm ]]; then
        DETECTED_DM="gdm"
    elif systemctl is-active --quiet lightdm 2>/dev/null || [[ -f /usr/bin/lightdm ]]; then
        DETECTED_DM="lightdm"
    fi
    step_info "Display Manager: ${DETECTED_DM}"

    # Export variables
    export IS_ARCH_COMPATIBLE DETECTED_GPU_VENDOR DETECTED_BOOTLOADER DETECTED_DM
    step_success "Hardware and system detection complete"
}
