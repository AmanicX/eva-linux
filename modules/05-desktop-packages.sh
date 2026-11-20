#!/usr/bin/env bash
# ==============================================================================
#  [05] Desktop Package Installation (Pacman & AUR)
# ==============================================================================

set -Eeuo pipefail

run_desktop_packages() {
    step_header 6 14 "Core Desktop Packages & Dependencies"

    # 1. Base Desktop & Wayland Packages (Arch Official Repositories)
    local pacman_packages=(
        # Compositor & Display Server
        niri
        xorg-server
        xorg-xwayland
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
        polkit-gnome
        wl-clipboard
        grim
        slurp
        
        # Qt6 Stack for Noctalia & Quickshell
        qt6-declarative
        qt6-svg
        qt6-wayland
        qt6-5compat
        qt6-virtualkeyboard
        qt6-multimedia-ffmpeg
        qt6-imageformats

        # Terminal, Shell & Modern CLI Utilities
        kitty
        zsh
        zsh-autosuggestions
        zsh-syntax-highlighting
        fastfetch
        btop
        ripgrep
        fd
        fzf
        bat
        eza
        zoxide
        jq

        # Developer Stack
        neovim
        tree-sitter-cli
        lazygit
        python
        python-pillow

        # Audio, Media & Utilities
        pipewire
        pipewire-pulse
        pipewire-alsa
        pipewire-jack
        wireplumber
        pavucontrol
        playerctl
        brightnessctl
        nautilus
        gnome-text-editor
        gnome-calculator
        loupe
        mpv
        file-roller
        gnome-disk-utility
        power-profiles-daemon
        bluez
        bluez-utils
        networkmanager

        # Fonts & Theming
        ttf-jetbrains-mono-nerd
        noto-fonts
        noto-fonts-cjk
        noto-fonts-emoji
        ttf-liberation
        adw-gtk-theme
        papirus-icon-theme

        # System & Boot
        sddm
        grub
        os-prober
        plymouth
    )

    # 2. GPU Driver Additions based on Hardware Detection
    if [[ "${DETECTED_GPU_VENDOR}" == "amd" ]]; then
        step_info "Configuring AMD Radeon graphics packages..."
        pacman_packages+=(vulkan-radeon libva-utils)
        # Add 32-bit driver if multilib is available
        if pacman -Si lib32-vulkan-radeon >/dev/null 2>&1; then
            pacman_packages+=(lib32-vulkan-radeon)
        fi
    elif [[ "${DETECTED_GPU_VENDOR}" == "intel" ]]; then
        step_info "Configuring Intel graphics packages..."
        pacman_packages+=(vulkan-intel intel-media-driver)
        if pacman -Si lib32-vulkan-intel >/dev/null 2>&1; then
            pacman_packages+=(lib32-vulkan-intel)
        fi
    elif [[ "${DETECTED_GPU_VENDOR}" == "nvidia" ]]; then
        step_info "Detected NVIDIA graphics hardware."
        if ask_confirm "Do you want to install NVIDIA proprietary drivers (nvidia-dkms)?" "y"; then
            pacman_packages+=(nvidia-dkms nvidia-utils egl-wayland)
            if pacman -Si lib32-nvidia-utils >/dev/null 2>&1; then
                pacman_packages+=(lib32-nvidia-utils)
            fi
        fi
    fi

    step_info "Installing official repository packages via pacman..."
    sudo pacman -S --needed --noconfirm "${pacman_packages[@]}"
    step_success "Official repository packages installed"

    # 3. AUR Packages (Noctalia, Quickshell, xwayland-satellite, oh-my-posh, matugen)
    local aur_packages=()

    # Check if packages are in official repos (e.g. noctalia/quickshell might be in extra on newer Arch)
    for pkg in noctalia quickshell xwayland-satellite matugen oh-my-posh-bin; do
        if pacman -Si "${pkg}" >/dev/null 2>&1; then
            step_info "Installing ${pkg} from official repositories..."
            sudo pacman -S --needed --noconfirm "${pkg}"
        else
            aur_packages+=("${pkg}")
        fi
    done

    if [[ ${#aur_packages[@]} -gt 0 ]]; then
        step_info "Installing AUR packages via ${AUR_HELPER}: ${aur_packages[*]}..."
        "${AUR_HELPER}" -S --needed --noconfirm "${aur_packages[@]}"
    fi

    step_success "All desktop packages and dependencies are installed"
}
