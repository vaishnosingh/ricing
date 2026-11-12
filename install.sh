#!/usr/bin/env bash
# ==============================================================================
# ⬤ Nothing OS Glyph Rice — One-Command Installer & Deployment Script
# Automatically creates a full backup snapshot before making any changes.
# Allows 1-command instant rollback via ./restore.sh if anything goes wrong.
# Compatible with Bash, Fish, Zsh across Linux distributions.
# ==============================================================================

set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/ricing-backups"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
BACKUP_DATA="$BACKUP_DIR/data"
MANIFEST="$BACKUP_DIR/manifest.txt"

# Terminal styling
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

say()     { printf "${RED}●${NC} %s\n" "$*"; }
info()    { printf "${BLUE}ℹ${NC} %s\n" "$*"; }
success() { printf "${GREEN}✓${NC} ${BOLD}%s${NC}\n" "$*"; }
warn()    { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
error()   { printf "${RED}✖${NC} %s\n" "$*"; }

# ── Trap on error for automatic rollback offer ────────────────────────────────
on_error() {
    local exit_code=$?
    echo ""
    error "An error occurred during installation (exit code: $exit_code)!"
    if [ -d "$BACKUP_DIR" ]; then
        warn "A complete backup of your previous desktop was saved at:"
        printf "  ${BOLD}%s${NC}\n\n" "$BACKUP_DIR"
        read -rp "Would you like to automatically rollback to your previous setup now? [Y/n]: " answer || true
        case "${answer:-Y}" in
            [yY]|[yY][eE][sS]|"")
                if [ -f "$DOTS/restore.sh" ]; then
                    bash "$DOTS/restore.sh" "$BACKUP_DIR"
                fi
                exit $exit_code
                ;;
            *)
                info "Rollback aborted. You can manually restore anytime by running: ./restore.sh"
                exit $exit_code
                ;;
        esac
    fi
    exit $exit_code
}
trap on_error ERR

# ── Arch Linux packages ───────────────────────────────────────────────────────
PACMAN=(
    base-devel git curl jq python
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    kitty fish starship fastfetch btop cava eza zoxide direnv
    thunar pavucontrol
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    zen-browser-bin
)

declare -A EXTRA=(
    [telegram]="telegram-desktop"
    [spotify]="spotify-launcher spicetify-cli spicetify-marketplace-bin"
    [clash]="clash-verge-rev-bin"
)

G=config/quickshell/glyph
# repo relative path -> target in $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "$G                                         .config/quickshell/glyph"
    "config/quickshell/rice                     .config/quickshell/rice"
    "config/quickshell/rice/rice                .local/bin/rice"
    "config/kitty                               .config/kitty"
    "config/qtengine                            .config/qtengine"
    "$G/term/qtengine.colors                    .config/qtengine.colors"
    "$G/term/starship.toml                      .config/starship.toml"
    "$G/term/fastfetch                          .config/fastfetch"
    "$G/term/btop                               .config/btop"
    "$G/term/cava                               .config/cava"
    "$G/term/gtk-3.0/gtk.css                    .config/gtk-3.0/gtk.css"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
    "nakshatra-calc                             .local/bin/nakshatra-calc"
    "systemd/nakshatra-calc.service             .config/systemd/user/nakshatra-calc.service"
    "systemd/nakshatra-calc.timer               .config/systemd/user/nakshatra-calc.timer"
)

# ── Step 1: Full Desktop Snapshot Backup ──────────────────────────────────────
backup_desktop() {
    say "Creating complete pre-installation backup snapshot..."
    mkdir -p "$BACKUP_DATA"

    # Header for manifest
    echo "# Ricing Backup Manifest - Created $(date)" > "$MANIFEST"
    echo "# Format: TYPE|REL_PATH|IS_SYMLINK|SYMLINK_TARGET" >> "$MANIFEST"

    # Potential collision list
    local targets=(
        ".config/hypr"
        ".config/quickshell"
        ".config/kitty"
        ".config/fish"
        ".config/qtengine"
        ".config/fastfetch"
        ".config/starship.toml"
        ".config/cava"
        ".config/btop"
        ".config/gtk-3.0"
        ".config/gtk-4.0"
        ".local/bin/rice"
        ".local/bin/nakshatra-calc"
        ".local/state/rice"
        ".config/systemd/user/nakshatra-calc.service"
        ".config/systemd/user/nakshatra-calc.timer"
    )

    for item in "${targets[@]}"; do
        local full_src="$HOME/$item"
        if [ -L "$full_src" ]; then
            local target_link; target_link=$(readlink "$full_src")
            echo "SYMLINK|$item|1|$target_link" >> "$MANIFEST"
            mkdir -p "$(dirname "$BACKUP_DATA/$item")"
            cp -P "$full_src" "$BACKUP_DATA/$item"
            printf "  saved symlink: ~/%s -> %s\n" "$item" "$target_link"
        elif [ -e "$full_src" ]; then
            echo "FILE|$item|0|" >> "$MANIFEST"
            mkdir -p "$(dirname "$BACKUP_DATA/$item")"
            cp -a "$full_src" "$BACKUP_DATA/$item"
            printf "  saved copy: ~/%s\n" "$item"
        fi
    done

    # Update latest symlink
    ln -sfn "$BACKUP_DIR" "$BACKUP_ROOT/latest"

    # Save backup info
    cat <<EOF > "$BACKUP_DIR/backup_info.txt"
Backup Date: $(date)
Hostname: $(hostname 2>/dev/null || echo "unknown")
User: $USER
Home: $HOME
Source Repo: $DOTS
Rollback Command: $DOTS/restore.sh "$BACKUP_DIR"
EOF

    success "Snapshot successfully saved to:"
    printf "  ${BOLD}%s${NC}\n" "$BACKUP_DIR"
    info "If you ever need to restore, run: ./restore.sh"
}

# ── Step 2: Package Management (Arch Linux) ───────────────────────────────────
install_arch_packages() {
    command -v pacman >/dev/null || return 0

    say "Checking & installing Arch Linux packages..."
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || sudo pacman -R $pa
    pacman -Q pulseaudio &>/dev/null && say "pacman will ask \"Remove pulseaudio?\" -- answer y, pipewire-pulse replaces it"
    sudo pacman -Syu --needed "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "Installing yay AUR helper..."
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "Installing AUR packages..."
    yay -S --needed --noconfirm "${AUR[@]}" || warn "Some AUR packages could not be installed"
}

# ── Step 3: Symlinking and Configuration ───────────────────────────────────────
deploy_configurations() {
    say "Deploying configurations and symlinks..."
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"

        # Check if already points to our destination
        if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
            continue
        fi

        # Safely remove existing link/file (already backed up in Step 1)
        if [ -L "$dst" ] || [ -e "$dst" ]; then
            rm -rf "$dst"
        fi

        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        printf "  linked: ~/%s -> %s\n" "${dst#"$HOME"/}" "$src"
    done

    # Ensure executable permissions on helper scripts
    chmod +x "$DOTS/nakshatra-calc" 2>/dev/null || true
    chmod +x "$DOTS/install.sh" "$DOTS/restore.sh" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/rice" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/nakshatra-calc" 2>/dev/null || true

    # Initialize State directory
    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"

    if [ -d "$DOTS/state" ]; then
        for sf in "$DOTS/state/"*.json; do
            local base_sf; base_sf="$(basename "$sf")"
            if [ ! -f "${XDG_STATE_HOME:-$HOME/.local/state}/rice/$base_sf" ]; then
                cp "$sf" "${XDG_STATE_HOME:-$HOME/.local/state}/rice/$base_sf"
            fi
        done
    fi

    mkdir -p "$HOME/Pictures/Wallpapers"

    # Font cache rebuild
    say "Rebuilding font cache..."
    fc-cache -f >/dev/null 2>&1 || true

    # Systemd user services
    if command -v systemctl >/dev/null 2>&1; then
        say "Enabling user services & astronomical timer..."
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nakshatra-calc.timer 2>/dev/null || true
    fi

    # GNOME Dark Mode integration
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
    fi
}

# ── Step 4: Hot Reload ────────────────────────────────────────────────────────
reload_desktop() {
    # If running inside active Hyprland session, reload configs
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        say "Reloading Hyprland configuration..."
        hyprctl reload >/dev/null 2>&1 || true
    fi

    # Restart rice if available
    if [ -x "$HOME/.local/bin/rice" ]; then
        say "Restarting QuickShell rice interface..."
        "$HOME/.local/bin/rice" restart >/dev/null 2>&1 || true
    fi
}

# ── CLI Options ───────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  (no args)        One-command full setup with automatic snapshot backup
  --links          Symlinks & configurations only (works on all Linux distros)
  --backup-only    Create a snapshot backup of your current setup and exit
  --restore [DIR]  Revert to the latest backup (or specified backup directory)
  --help           Display this help guide

Rollback:
  If anything goes wrong, restore your desktop anytime by running:
    ./restore.sh
EOF
}

[ "$EUID" -eq 0 ] && { error "Please run as your normal user, not as root (sudo will be called if required)."; exit 1; }

case "${1:-}" in
    --help|-h)
        show_help
        ;;
    --restore)
        shift
        if [ -f "$DOTS/restore.sh" ]; then
            exec bash "$DOTS/restore.sh" "$@"
        else
            error "restore.sh not found in $DOTS"
        fi
        ;;
    --backup-only)
        backup_desktop
        ;;
    --links)
        backup_desktop
        deploy_configurations
        reload_desktop
        echo ""
        success "Installation completed successfully in symlink mode!"
        info "To revert to your previous setup at any time, run: ./restore.sh"
        ;;
    "")
        backup_desktop
        if command -v pacman >/dev/null 2>&1; then
            install_arch_packages
        else
            info "Non-Arch Linux detected. Proceeding with configuration deployment..."
        fi
        deploy_configurations
        reload_desktop
        echo ""
        success "Installation completed successfully!"
        info "To revert to your previous setup at any time, run: ./restore.sh"
        ;;
    *)
        error "Unknown option: $1 (run './install.sh --help' for usage)"
        ;;
esac
