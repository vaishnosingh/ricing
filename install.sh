#!/usr/bin/env bash
# ==============================================================================
# ⬤ NOTHING OS GLYPH RICE — FULLY DYNAMIC INTERACTIVE INSTALLER & WIZARD
# ==============================================================================
# Compatible with ANY Linux distribution and ANY Hyprland configuration.
# Confirms up-front, creates an immediate complete backup of your desktop,
# then automatically guides you through granular customization questions
# and deploys your custom Nothing OS desktop live.
# ==============================================================================

set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/ricing-backups"
TIMESTAMP="$(date +%Y-%m-%d_%H-%M-%S)"
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
BACKUP_DATA="$BACKUP_DIR/data"
MANIFEST="$BACKUP_DIR/manifest.txt"

# ── Terminal Colors & Formatting ──────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    MAGENTA=$'\033[0;35m'
    CYAN=$'\033[0;36m'
    WHITE=$'\033[1;37m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    UNDERLINE=$'\033[4m'
    NC=$'\033[0m'
else
    RED='' GREEN='' BLUE='' YELLOW='' MAGENTA='' CYAN='' WHITE='' BOLD='' DIM='' UNDERLINE='' NC=''
fi

say()     { printf "${RED}●${NC} %b\n" "$*"; }
info()    { printf "${BLUE}ℹ${NC} %b\n" "$*"; }
success() { printf "${GREEN}✓${NC} ${BOLD}%b${NC}\n" "$*"; }
warn()    { printf "${YELLOW}⚠${NC} %b\n" "$*"; }
error()   { printf "${RED}✖${NC} %b\n" "$*"; }
bullet()  { printf "  ${DIM}•${NC} %b\n" "$*"; }
step_head() {
    local num="$1"
    local title="$2"
    local desc="${3:-}"
    printf "\n${BOLD}${CYAN}┌─[ Step %s: %s ]${NC}\n" "$num" "$title"
    if [ -n "$desc" ]; then
        printf "${CYAN}│${NC}  ${DIM}%s${NC}\n" "$desc"
    fi
    printf "${CYAN}└─────────────────────────────────────────────────────────────────${NC}\n"
}

# ── Trap on error for automatic rollback offer ────────────────────────────────
cleanup_compositor() {
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        hyprctl eval "hl.config({ misc = { disable_autoreload = false } })" >/dev/null 2>&1 || true
        hyprctl keyword misc:disable_autoreload 0 >/dev/null 2>&1 || true
    fi
}
trap cleanup_compositor INT TERM

# ── Compositor Freeze & Atomic Single-Pass Reload (Prevents Screen Flashing) ──
freeze_compositor() {
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        # Suspend Hyprland inotify auto-reload so file writes don't flicker/flash the display
        hyprctl eval "hl.config({ misc = { disable_autoreload = true } })" >/dev/null 2>&1 || true
        hyprctl keyword misc:disable_autoreload 1 >/dev/null 2>&1 || true
    fi
}

unfreeze_and_atomic_reload() {
    local target_scale="${1:-}"
    local current_scale="${2:-}"

    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        say "Applying desktop configuration smoothly in a single atomic pass..."

        # 1. Single unified reload: Hyprland re-reads hyprland.lua, misc.lua, variables.lua in ONE pass
        # misc.lua restores disable_autoreload = false cleanly without triggering multiple reload loops
        hyprctl reload >/dev/null 2>&1 || true

        # 2. Only invoke monitor scaling if the requested scale differs from the currently active scale
        if [ -n "$target_scale" ] && [ "$target_scale" != "auto" ]; then
            if [ "$target_scale" != "$current_scale" ]; then
                hyprctl eval "hl.monitor({ output = '', mode = 'highres', position = 'auto', scale = $target_scale })" >/dev/null 2>&1 || true
            fi
        fi
    fi

    # 3. Synchronize QuickShell daemon cleanly without destroying window surfaces
    if [ -x "$HOME/.local/bin/rice" ]; then
        if ! pgrep -f 'qs .*glyph' >/dev/null 2>&1; then
            "$HOME/.local/bin/rice" start >/dev/null 2>&1 || true
        fi
    fi

    # 4. Silent font cache notification to terminal (zero flicker)
    if command -v pkill >/dev/null 2>&1; then
        pkill -USR1 kitty 2>/dev/null || true
    fi
}

on_error() {
    local exit_code=$?
    cleanup_compositor
    echo ""
    error "An error occurred during installation (exit code: $exit_code)!"
    if [ -d "$BACKUP_DIR" ]; then
        warn "A complete backup snapshot of your previous desktop was saved at:"
        printf "  ${BOLD}%s${NC}\n\n" "$BACKUP_DIR"
        printf "Would you like to automatically rollback to your previous setup now? [Y/n]: "
        read -r answer || true
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

# ── Package Definitions Across Linux Distributions ───────────────────────────
ARCH_PKGS=(
    base-devel git curl jq python
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips qalculate libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    kitty fish starship fastfetch btop cava eza zoxide direnv
    thunar pavucontrol
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)
ARCH_AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin zen-browser-bin
)

FEDORA_PKGS=(
    git curl jq python3 python3-pip python3-devel gcc gcc-c++ make
    hyprland hypridle hyprsunset xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm gnome-keyring geoclue2 upower xdg-user-dirs
    pipewire pipewire-pulseaudio wireplumber NetworkManager bluez power-profiles-daemon
    brightnessctl playerctl wl-clipboard grim slurp swappy ImageMagick qalculate
    kitty fish starship fastfetch btop cava eza zoxide
    thunar pavucontrol libnotify
    google-noto-sans-fonts google-noto-color-emoji-fonts papirus-icon-theme adw-gtk3-theme
)

DEBIAN_PKGS=(
    git curl jq python3 python3-pip python3-venv python3-dev build-essential
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm gnome-keyring geoclue-2.0 upower xdg-user-dirs
    pipewire pipewire-pulse wireplumber network-manager bluez
    brightnessctl playerctl wl-clipboard grim slurp swappy imagemagick
    kitty fish
    thunar pavucontrol libnotify-bin
    fonts-noto-core fonts-noto-color-emoji papirus-icon-theme
)

ZYPPER_PKGS=(
    git curl jq python3 python3-pip python3-devel gcc gcc-c++ make
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm gnome-keyring geoclue2 upower xdg-user-dirs
    pipewire pipewire-pulseaudio wireplumber NetworkManager bluez
    brightnessctl playerctl wl-clipboard grim slurp swappy ImageMagick qalculate
    kitty fish starship fastfetch btop
    thunar pavucontrol libnotify-tools
    noto-sans-fonts noto-coloremoji-fonts papirus-icon-theme
)

VOID_PKGS=(
    git curl jq python3 python3-pip python3-devel base-devel
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    elogind polkit-gnome upower
    pipewire wireplumber
    brightnessctl playerctl wl-clipboard grim slurp swappy ImageMagick qalculate
    kitty fish starship fastfetch btop
    thunar pavucontrol libnotify
    noto-fonts-ttf papirus-icon-theme
)

ALPINE_PKGS=(
    git curl jq python3 py3-pip python3-dev build-base
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    pipewire wireplumber
    brightnessctl playerctl wl-clipboard grim slurp swappy imagemagick
    kitty fish starship fastfetch btop
    thunar pavucontrol libnotify
)

G=config/quickshell/glyph
STANDALONE_LINKS=(
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
    "config/wireplumber                         .config/wireplumber"
    "nakshatra-calc                             .local/bin/nakshatra-calc"
    "systemd/nakshatra-calc.service             .config/systemd/user/nakshatra-calc.service"
    "systemd/nakshatra-calc.timer               .config/systemd/user/nakshatra-calc.timer"
)

OVERLAY_LINKS=(
    "$G                                         .config/quickshell/glyph"
    "config/quickshell/rice                     .config/quickshell/rice"
    "config/quickshell/rice/rice                .local/bin/rice"
    "config/fonts                               .local/share/fonts/glyph"
    "config/wireplumber                         .config/wireplumber"
    "nakshatra-calc                             .local/bin/nakshatra-calc"
    "systemd/nakshatra-calc.service             .config/systemd/user/nakshatra-calc.service"
    "systemd/nakshatra-calc.timer               .config/systemd/user/nakshatra-calc.timer"
)

# ── Interactive TUI Helpers ───────────────────────────────────────────────────
print_banner() {
    clear 2>/dev/null || true
    printf "${RED}"
    cat << "EOF"
  ██████╗ ██╗  ██╗   ██╗██████╗ ██╗  ██╗    ██████╗ ██╗ ██████╗███████╗
 ██╔════╝ ██║  ╚██╗ ██╔╝██╔══██╗██║  ██║    ██╔══██╗██║██╔════╝██╔════╝
 ██║  ███╗██║   ╚████╔╝ ██████╔╝███████║    ██████╔╝██║██║     █████╗  
 ██║   ██║██║    ╚██╔╝  ██╔═══╝ ██╔══██║    ██╔══██╗██║██║     ██╔══╝  
 ╚██████╔╝███████╗██║   ██║     ██║  ██║    ██║  ██║██║╚██████╗███████╗
  ╚═════╝ ╚══════╝╚═╝   ╚═╝     ╚═╝  ╚═╝    ╚═╝  ╚═╝╚═╝ ╚═════╝╚══════╝
EOF
    printf "${NC}\n"
    printf "  ${BOLD}⬤ Nothing OS Glyph Rice · Universal Dynamic Customizer & Installer${NC}\n"
    printf "  ${DIM}Engineered for PC Desktops & Laptops on any Linux Distribution${NC}\n"
    printf "  ${DIM}───────────────────────────────────────────────────────────────────${NC}\n\n"
}

box_header() {
    local title="$1"
    local desc="${2:-}"
    printf "\n${BOLD}${CYAN}┌─[ %s ]${NC}\n" "$title"
    if [ -n "$desc" ]; then
        printf "${CYAN}│${NC}  ${DIM}%s${NC}\n" "$desc"
    fi
    printf "${CYAN}└─────────────────────────────────────────────────────────────────${NC}\n"
}

prompt_choice() {
    local prompt_text="$1"
    local default_val="$2"
    local max_val="$3"
    local choice=""

    while true; do
        printf "${BOLD}${WHITE}%s${NC} [1-%s] (Default: ${GREEN}%s${NC}): " "$prompt_text" "$max_val" "$default_val" >&2
        read -r choice || true
        choice="${choice:-$default_val}"
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$max_val" ]; then
            echo "$choice"
            return 0
        fi
        warn "Invalid selection. Please enter a number between 1 and $max_val." >&2
    done
}

prompt_yes_no() {
    local prompt_text="$1"
    local default_val="${2:-Y}"
    local answer=""

    local prompt_suffix="[Y/n]"
    [ "$default_val" = "N" ] && prompt_suffix="[y/N]"

    printf "${BOLD}${WHITE}%s${NC} %s: " "$prompt_text" "$prompt_suffix" >&2
    read -r answer || true
    answer="${answer:-$default_val}"
    case "$answer" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

prompt_text() {
    local prompt_text="$1"
    local default_val="$2"
    local result=""

    printf "${BOLD}${WHITE}%s${NC} (Default: ${GREEN}%s${NC}): " "$prompt_text" "$default_val" >&2
    read -r result || true
    echo "${result:-$default_val}"
}

# ── Dynamic Hardware & Environment Probing Engine ─────────────────────────────
detect_os() {
    local id="unknown"
    local pretty="Generic Linux"
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        id="${ID:-unknown}"
        pretty="${PRETTY_NAME:-$id}"
    elif [ -f /etc/arch-release ]; then
        id="arch"; pretty="Arch Linux"
    elif [ -f /etc/fedora-release ]; then
        id="fedora"; pretty="Fedora Linux"
    elif [ -f /etc/debian_version ]; then
        id="debian"; pretty="Debian Linux"
    fi

    local family="generic"
    case "$id" in
        arch|endeavouros|manjaro|cachyos|garuda|artix)
            family="arch" ;;
        fedora|rhel|centos|nobara|ultramarine|rocky|almalinux)
            family="fedora" ;;
        debian|ubuntu|pop|linuxmint|elementary|kali|raspbian)
            family="debian" ;;
        opensuse*|suse|tumbleweed|leap)
            family="opensuse" ;;
        void)
            family="void" ;;
        alpine)
            family="alpine" ;;
        nixos)
            family="nixos" ;;
        *)
            if [ -n "${ID_LIKE:-}" ]; then
                for l in $ID_LIKE; do
                    case "$l" in
                        arch) family="arch"; break ;;
                        fedora) family="fedora"; break ;;
                        debian) family="debian"; break ;;
                        suse) family="opensuse"; break ;;
                    esac
                done
            fi
            ;;
    esac

    echo "$family|$pretty|$id"
}

detect_chassis_and_battery() {
    local is_laptop=0
    local battery_info="None"
    local chassis="Desktop PC"

    # Check for battery in sysfs
    local bats
    bats=$(find /sys/class/power_supply -name "BAT*" 2>/dev/null || true)
    if [ -n "$bats" ]; then
        is_laptop=1
        local bat_name
        bat_name=$(basename "$(echo "$bats" | head -1)")
        local bat_cap="100%"
        [ -f "/sys/class/power_supply/$bat_name/capacity" ] && bat_cap="$(cat "/sys/class/power_supply/$bat_name/capacity")%"
        battery_info="$bat_name ($bat_cap)"
        chassis="Laptop"
    fi

    # Check SMBIOS chassis type
    if [ -f /sys/class/dmi/id/chassis_type ]; then
        local ctype
        ctype=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo 0)
        case "$ctype" in
            8|9|10|11|14|30|31|32)
                is_laptop=1
                chassis="Laptop/Notebook"
                ;;
            3|4|5|6|7|15|16|23|24|35)
                [ -z "$bats" ] && is_laptop=0 && chassis="Desktop Tower"
                ;;
        esac
    fi

    echo "$is_laptop|$chassis|$battery_info"
}

detect_gpu() {
    local gpu="Unknown GPU"
    if command -v lspci >/dev/null 2>&1; then
        local lspci_out
        lspci_out=$(lspci -nnk 2>/dev/null | grep -i -E "vga|3d|display" | head -1 || true)
        if [ -n "$lspci_out" ]; then
            if echo "$lspci_out" | grep -iq "intel"; then
                gpu="Intel HD/Iris/Arc Graphics"
            elif echo "$lspci_out" | grep -iq "nvidia"; then
                gpu="NVIDIA GeForce / RTX"
            elif echo "$lspci_out" | grep -iq -E "amd|ati|radeon"; then
                gpu="AMD Radeon Graphics"
            else
                gpu=$(echo "$lspci_out" | cut -d: -f3- | awk '{$1=$1};1')
            fi
        fi
    fi
    echo "$gpu"
}

detect_hyprland_setup() {
    local hypr_dir="$HOME/.config/hypr"
    local status="none"
    local type="none"
    local line_count=0
    local is_running=0

    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        is_running=1
    fi

    if [ -d "$hypr_dir" ]; then
        if [ -L "$hypr_dir" ]; then
            status="symlink"
        else
            status="directory"
        fi

        if [ -f "$hypr_dir/hyprland.lua" ]; then
            type="lua"
            line_count=$(wc -l < "$hypr_dir/hyprland.lua" 2>/dev/null || echo 0)
        elif [ -f "$hypr_dir/hyprland.conf" ]; then
            type="conf"
            line_count=$(wc -l < "$hypr_dir/hyprland.conf" 2>/dev/null || echo 0)
        fi
    fi

    echo "$status|$type|$line_count|$is_running"
}

detect_display_info() {
    local name="" res="" hz="" scale="1.0" count=1
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        local mon_json
        mon_json=$(hyprctl monitors -j 2>/dev/null || true)
        if [ -n "$mon_json" ] && command -v jq >/dev/null 2>&1; then
            count=$(echo "$mon_json" | jq '. | length' 2>/dev/null || echo 1)
            name=$(echo "$mon_json" | jq -r '.[0].name // empty')
            local w h
            w=$(echo "$mon_json" | jq -r '.[0].width // empty')
            h=$(echo "$mon_json" | jq -r '.[0].height // empty')
            [ -n "$w" ] && [ -n "$h" ] && res="${w}x${h}"
            local r
            r=$(echo "$mon_json" | jq -r '.[0].refreshRate // empty')
            [ -n "$r" ] && hz="$(printf "%.0f" "$r")Hz"
            scale=$(echo "$mon_json" | jq -r '.[0].scale // 1.0')
        fi
    fi

    if [ -z "$res" ] && command -v wlr-randr >/dev/null 2>&1; then
        res=$(wlr-randr 2>/dev/null | grep -E "^\s+[0-9]+x[0-9]+" | head -1 | awk '{print $1}' || true)
    fi

    echo "${name:-eDP-1}|${res:-1920x1080}|${hz:-60Hz}|${scale:-1.0}|$count"
}

detect_touchpad_device() {
    local dev_name=""
    if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        dev_name=$(hyprctl devices 2>/dev/null | grep -i "touchpad" -B 1 | grep -v "touchpad" | grep -oE "ven_[^:]+:[^:]+-[^:]+" | head -1 || true)
        if [ -z "$dev_name" ]; then
            dev_name=$(hyprctl devices 2>/dev/null | grep -i -E "touchpad|trackpad" | head -1 | awk '{$1=$1};1' || true)
        fi
    fi

    if [ -z "$dev_name" ] && [ -d /dev/input ]; then
        if command -v libinput >/dev/null 2>&1; then
            dev_name=$(libinput list-devices 2>/dev/null | grep -i "Device:" | grep -i -E "touchpad|trackpad" | head -1 | cut -d: -f2 | awk '{$1=$1};1' || true)
        fi
    fi

    echo "${dev_name:-Generic Touchpad}"
}

detect_installed_apps() {
    local terms=()
    for t in kitty alacritty foot ghostty wezterm gnome-terminal; do
        command -v "$t" >/dev/null 2>&1 && terms+=("$t")
    done

    local browsers=()
    for b in brave-browser brave zen-browser zen firefox google-chrome-stable google-chrome chromium; do
        command -v "$b" >/dev/null 2>&1 && browsers+=("$b")
    done

    local fms=()
    for f in thunar nautilus dolphin yazi nemo ranger; do
        command -v "$f" >/dev/null 2>&1 && fms+=("$f")
    done

    local primary_term="${terms[0]:-kitty}"
    local primary_browser="${browsers[0]:-brave-browser}"
    local primary_fm="${fms[0]:-thunar}"

    echo "$primary_term|$primary_browser|$primary_fm"
}

# ── Non-Destructive Backup & Rollback Engine ──────────────────────────────────
backup_desktop() {
    say "Creating complete pre-installation backup snapshot of your current Hyprland desktop..."
    mkdir -p "$BACKUP_DATA"

    echo "# Ricing Backup Manifest - Created $(date)" > "$MANIFEST"
    echo "# Format: TYPE|REL_PATH|IS_SYMLINK|SYMLINK_TARGET" >> "$MANIFEST"

    local targets=(
        ".config/hypr"
        ".config/quickshell"
        ".config/waybar"
        ".config/rofi"
        ".config/wofi"
        ".config/mako"
        ".config/dunst"
        ".config/swaync"
        ".config/eww"
        ".config/ags"
        ".config/kitty"
        ".config/alacritty"
        ".config/foot"
        ".config/ghostty"
        ".config/wezterm"
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
        ".config/demonshot"
        ".config/systemd/user/nakshatra-calc.service"
        ".config/systemd/user/nakshatra-calc.timer"
    )

    local count=0
    for item in "${targets[@]}"; do
        local full_src="$HOME/$item"
        if [ -L "$full_src" ]; then
            local target_link; target_link=$(readlink "$full_src")
            echo "SYMLINK|$item|1|$target_link" >> "$MANIFEST"
            mkdir -p "$(dirname "$BACKUP_DATA/$item")"
            cp -P "$full_src" "$BACKUP_DATA/$item"
            printf "  saved symlink: ~/%s -> %s\n" "$item" "$target_link"
            count=$((count + 1))
        elif [ -e "$full_src" ]; then
            echo "FILE|$item|0|" >> "$MANIFEST"
            mkdir -p "$(dirname "$BACKUP_DATA/$item")"
            cp -a "$full_src" "$BACKUP_DATA/$item"
            printf "  saved copy: ~/%s\n" "$item"
            count=$((count + 1))
        fi
    done

    ln -sfn "$BACKUP_DIR" "$BACKUP_ROOT/latest"

    cat <<EOF > "$BACKUP_DIR/backup_info.txt"
Backup Date: $(date)
Hostname: $(hostname 2>/dev/null || echo "unknown")
User: $USER
Home: $HOME
Source Repo: $DOTS
Items Backed Up: $count
Rollback Command: $DOTS/restore.sh "$BACKUP_DIR"
EOF

    success "Complete backup snapshot ($count items) successfully saved to:"
    printf "  ${BOLD}%s${NC}\n" "$BACKUP_DIR"
    info "If you ever need to restore your previous desktop, you can run: ./restore.sh\n"
}

# ── Distribution Package Manager ──────────────────────────────────────────────
install_packages_interactive() {
    local family="$1"
    local pretty="$2"

    step_head "3" "Distribution Package Management" "Detected OS: $pretty ($family family)"
    printf "  ${BOLD}1${NC}) Install full recommended packages via %s (Best experience)\n" "$family"
    printf "  ${BOLD}2${NC}) Install essential core packages only (Hyprland, QuickShell, Python)\n"
    printf "  ${BOLD}3${NC}) Skip package manager (Use existing system binaries)\n"
    local p_choice; p_choice=$(prompt_choice "Select package installation mode" "1" 3)

    [ "$p_choice" -eq 3 ] && { info "Skipping package manager phase."; return 0; }

    say "Installing system packages for $pretty..."

    case "$family" in
        arch)
            command -v pacman >/dev/null || { warn "pacman not found, skipping"; return 0; }
            sudo pacman -Syu --needed "${ARCH_PKGS[@]}"

            if command -v yay >/dev/null; then
                say "Installing AUR packages via yay..."
                yay -S --needed --noconfirm "${ARCH_AUR[@]}" || warn "Some AUR packages could not be installed"
            elif command -v paru >/dev/null; then
                say "Installing AUR packages via paru..."
                paru -S --needed --noconfirm "${ARCH_AUR[@]}" || warn "Some AUR packages could not be installed"
            fi
            ;;
        fedora)
            command -v dnf >/dev/null || { warn "dnf not found, skipping"; return 0; }
            sudo dnf install -y "${FEDORA_PKGS[@]}" || warn "Some Fedora packages could not be installed from standard repos"

            if ! command -v quickshell >/dev/null 2>&1; then
                info "Checking QuickShell in Fedora Copr (solopasha/hyprland)..."
                if sudo dnf copr enable -y solopasha/hyprland 2>/dev/null; then
                    sudo dnf install -y quickshell 2>/dev/null || warn "QuickShell could not be installed from Copr."
                fi
            fi
            ;;
        debian)
            command -v apt-get >/dev/null || { warn "apt-get not found, skipping"; return 0; }
            sudo apt-get update
            sudo apt-get install -y "${DEBIAN_PKGS[@]}" || warn "Some Debian packages could not be installed automatically"
            ;;
        opensuse)
            command -v zypper >/dev/null || { warn "zypper not found, skipping"; return 0; }
            sudo zypper install -y "${ZYPPER_PKGS[@]}" || warn "Some openSUSE packages could not be installed automatically"
            ;;
        void)
            command -v xbps-install >/dev/null || { warn "xbps-install not found, skipping"; return 0; }
            sudo xbps-install -Sy "${VOID_PKGS[@]}" || warn "Some Void packages could not be installed automatically"
            ;;
        alpine)
            command -v apk >/dev/null || { warn "apk not found, skipping"; return 0; }
            sudo apk add "${ALPINE_PKGS[@]}" || warn "Some Alpine packages could not be installed automatically"
            ;;
        *)
            info "Non-standard Linux distribution. Skipping automatic package manager."
            info "Please verify Hyprland, QuickShell, and Python3 are installed on your system."
            ;;
    esac

    success "Package configuration phase completed."
}

# ── Python Astronomical Calculation Engine ────────────────────────────────────
setup_python_env() {
    say "Setting up astronomical calculation engine (Swiss Ephemeris)..."
    local venv_dir="$HOME/.local/share/rice/venv"

    if python3 -c "import swisseph" >/dev/null 2>&1; then
        success "Swiss Ephemeris (pyswisseph) is available in current Python environment."
        return 0
    fi

    if [ -f "$HOME/extras/local_venv/bin/python3" ] && "$HOME/extras/local_venv/bin/python3" -c "import swisseph" >/dev/null 2>&1; then
        success "Swiss Ephemeris found in ~/extras/local_venv."
        return 0
    fi

    if [ ! -f "$venv_dir/bin/python3" ]; then
        info "Creating isolated Python environment at $venv_dir (bypasses PEP 668 restrictions)..."
        mkdir -p "$(dirname "$venv_dir")"
        python3 -m venv "$venv_dir" 2>/dev/null || python3 -m virtualenv "$venv_dir" 2>/dev/null || true
    fi

    if [ -x "$venv_dir/bin/pip" ]; then
        if ! "$venv_dir/bin/python3" -c "import swisseph" >/dev/null 2>&1; then
            info "Installing pyswisseph into $venv_dir..."
            "$venv_dir/bin/pip" install --quiet pyswisseph || warn "Could not install pyswisseph automatically. Please run: pip install pyswisseph"
        fi
        success "Swiss Ephemeris ready in $venv_dir."
    fi
}

# ── Standalone Deployment Engine ──────────────────────────────────────────────
deploy_standalone() {
    local symlink_mode="${1:-true}"
    say "Deploying Nothing OS Glyph Rice files..."

    for l in "${STANDALONE_LINKS[@]}"; do
        local src dst
        read -r src dst <<<"$l"
        src="$DOTS/$src"
        dst="$HOME/$dst"

        if [ "$symlink_mode" = true ]; then
            if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
                continue
            fi
            [ -L "$dst" ] || [ -e "$dst" ] && rm -rf "$dst"
            mkdir -p "$(dirname "$dst")"
            ln -s "$src" "$dst"
            printf "  linked: ~/%s -> %s\n" "${dst#"$HOME"/}" "$src"
        else
            [ -L "$dst" ] || [ -e "$dst" ] && rm -rf "$dst"
            mkdir -p "$(dirname "$dst")"
            cp -a "$src" "$dst"
            printf "  copied: ~/%s\n" "${dst#"$HOME"/}"
        fi
    done

    chmod +x "$DOTS/nakshatra-calc" "$DOTS/install.sh" "$DOTS/restore.sh" 2>/dev/null || true
    chmod +x "$HOME/.local/bin/rice" "$HOME/.local/bin/nakshatra-calc" 2>/dev/null || true

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

    say "Rebuilding font cache..."
    fc-cache -f >/dev/null 2>&1 || true

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nakshatra-calc.timer 2>/dev/null || true
    fi

    success "File deployment phase completed."
}

# ── Modular Overlay Engine (Coexist with ANY Hyprland Setup) ───────────────────
deploy_overlay() {
    local hypr_dir="$HOME/.config/hypr"
    local overlay_conf="$hypr_dir/glyph-overlay.conf"
    local overlay_lua="$hypr_dir/glyph-overlay.lua"

    say "Deploying Nothing OS Glyph Rice as a Modular Coexistence Overlay..."
    info "Your existing Hyprland configuration and window rules will remain untouched."

    for l in "${OVERLAY_LINKS[@]}"; do
        local src dst
        read -r src dst <<<"$l"
        src="$DOTS/$src"
        dst="$HOME/$dst"

        [ -L "$dst" ] || [ -e "$dst" ] && rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        printf "  linked: ~/%s -> %s\n" "${dst#"$HOME"/}" "$src"
    done

    mkdir -p "$hypr_dir"
    cat << 'EOF' > "$overlay_conf"
# ==============================================================================
# ⬤ NOTHING OS GLYPH RICE — MODULAR OVERLAY MODULE
# Source this file from your main ~/.config/hypr/hyprland.conf:
#   source = ~/.config/hypr/glyph-overlay.conf
# ==============================================================================

# Autostart Nothing OS Glyph Shell Daemon
exec-once = ~/.config/quickshell/rice/rice start

# Layer rules for Nothing OS QuickShell UI
layerrule = noanim, glyph-.*
layerrule = fade, glyph-power

# Global Shortcuts for Nothing OS Widgets
bind = SUPER, Space, global, shell:altar
bind = SUPER, I, global, shell:settings
bind = SUPER, A, global, shell:quick
bind = SUPER, V, global, shell:clip
bind = SUPER, Period, global, shell:charms
bind = SUPER SHIFT, W, global, shell:wall
bind = , Print, global, shell:shot
bind = SUPER, P, global, shell:pact

# Calibrated 1:1 Trackpad Gestures (Swipe distance: 250px)
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 250
    workspace_swipe_cancel_ratio = 0.15
    workspace_swipe_min_speed_to_force = 5
    workspace_swipe_direction_lock = true
    workspace_swipe_direction_lock_threshold = 5
    workspace_swipe_create_new = true
}

gesture = 3, horizontal, workspace
gesture = 3, up, global, shell:launcher
gesture = 3, down, global, shell:altar
gesture = 3, pinchin, exec, kitty
gesture = 3, pinchout, exec, brave-browser
gesture = 4, up, special, special
gesture = 4, down, close
gesture = 4, pinchin, exec, thunar
gesture = 4, pinchout, global, shell:settings
gesture = 5, down, exec, systemctl suspend
EOF

    cat << 'EOF' > "$overlay_lua"
-- Nothing OS Glyph Rice Lua Overlay Companion
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.config/quickshell/rice/rice start")
end)

hl.layer_rule({ match = { namespace = "glyph-power" }, animation = "fade" })
hl.layer_rule({ match = { namespace = "glyph-(launcher|edge|island|buds|quick|home|bar|caffeine|shot|clip|charms|vpn|deck|prefs|hot|cal|wall|back)" }, no_anim = true })

-- Globals
hl.bind("SUPER + Space", hl.dsp.global("shell:altar"))
hl.bind("SUPER + I", hl.dsp.global("shell:settings"))
hl.bind("SUPER + A", hl.dsp.global("shell:quick"))
hl.bind("SUPER + V", hl.dsp.global("shell:clip"))
hl.bind("SUPER + Period", hl.dsp.global("shell:charms"))
hl.bind("SUPER + SHIFT + W", hl.dsp.global("shell:wall"))
hl.bind("Print", hl.dsp.global("shell:shot"))

-- Calibrated Gestures
hl.config({
    gestures = {
        workspace_swipe_distance                 = 250,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 5,
        workspace_swipe_create_new               = true,
    },
})
EOF

    success "Created modular overlay files:"
    bullet "$overlay_conf"
    bullet "$overlay_lua"

    if [ -f "$hypr_dir/hyprland.conf" ]; then
        if grep -q "glyph-overlay.conf" "$hypr_dir/hyprland.conf" 2>/dev/null; then
            info "glyph-overlay.conf is already sourced in your hyprland.conf."
        else
            echo ""
            info "To activate Glyph Rice inside your existing setup, add this line to your hyprland.conf:"
            printf "  ${BOLD}${GREEN}source = ~/.config/hypr/glyph-overlay.conf${NC}\n\n"
            if prompt_yes_no "Would you like the installer to automatically append this line for you?" "Y"; then
                echo "" >> "$hypr_dir/hyprland.conf"
                echo "# ── Nothing OS Glyph Rice Overlay ──" >> "$hypr_dir/hyprland.conf"
                echo "source = ~/.config/hypr/glyph-overlay.conf" >> "$hypr_dir/hyprland.conf"
                success "Appended source line to ~/.config/hypr/hyprland.conf."
            fi
        fi
    elif [ -f "$hypr_dir/hyprland.lua" ]; then
        if grep -q "glyph-overlay" "$hypr_dir/hyprland.lua" 2>/dev/null; then
            info "glyph-overlay is already required in your hyprland.lua."
        else
            echo ""
            info "To activate Glyph Rice inside your existing setup, add this line to your hyprland.lua:"
            printf "  ${BOLD}${GREEN}require('glyph-overlay')${NC}\n\n"
            if prompt_yes_no "Would you like the installer to automatically append this line for you?" "Y"; then
                echo "" >> "$hypr_dir/hyprland.lua"
                echo "-- Nothing OS Glyph Rice Overlay" >> "$hypr_dir/hyprland.lua"
                echo "require('glyph-overlay')" >> "$hypr_dir/hyprland.lua"
                success "Appended require line to ~/.config/hypr/hyprland.lua."
            fi
        fi
    fi

    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"

    say "Rebuilding font cache..."
    fc-cache -f >/dev/null 2>&1 || true

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nakshatra-calc.timer 2>/dev/null || true
    fi

    success "Modular overlay deployment completed successfully."
}

# ── Master Configuration Writer ───────────────────────────────────────────────
apply_user_customizations() {
    local pref_term="$1"
    local pref_browser="$2"
    local pref_fm="$3"
    local pref_shell="$4"
    local selected_scale="$5"
    local selected_distance="$6"
    local palette_idx="$7"
    local rounding_val="$8"
    local gaps_in="$9"
    local gaps_out="${10}"
    local blur_val="${11}"
    local shadow_val="${12}"
    local natural_scroll="${13}"
    local tap_click="${14}"
    local disable_typing="${15}"
    local cursor_theme="${16}"
    local cursor_size="${17}"
    local font_family="${18}"
    local font_size="${19}"
    local user_name="${20}"
    local clock_24="${21}"
    local stars_val="${22}"
    local grid_val="${23}"
    local moon_pos="${24}"

    say "Applying your customized settings across all configuration files..."

    # 1. Update variables.lua safely via Python
    python3 - <<EOF
import re

file_path = "$DOTS/config/hypr/variables.lua"
with open(file_path, "r") as f:
    c = f.read()

replacements = [
    (r'terminal\s*=\s*"[^"]*"', 'terminal                   = "$pref_term"'),
    (r'browser\s*=\s*"[^"]*"', 'browser                    = "$pref_browser"'),
    (r'fileExplorer\s*=\s*"[^"]*"', 'fileExplorer               = "$pref_fm"'),
    (r'fileManager\s*=\s*"[^"]*"', 'fileManager                = "$pref_fm"'),
    (r'windowRounding\s*=\s*[0-9]+', 'windowRounding             = $rounding_val'),
    (r'windowGapsIn\s*=\s*[0-9]+', 'windowGapsIn               = $gaps_in'),
    (r'windowGapsOut\s*=\s*[0-9]+', 'windowGapsOut              = $gaps_out'),
    (r'blurEnabled\s*=\s*(true|false)', 'blurEnabled                = $blur_val'),
    (r'shadowEnabled\s*=\s*(true|false)', 'shadowEnabled              = $shadow_val'),
    (r'cursorTheme\s*=\s*"[^"]*"', 'cursorTheme                = "$cursor_theme"'),
    (r'cursorSize\s*=\s*[0-9]+', 'cursorSize                 = $cursor_size'),
    (r'touchpadDisableTyping\s*=\s*(true|false)', 'touchpadDisableTyping      = $disable_typing'),
]

for pat, repl in replacements:
    c = re.sub(pat, repl, c)

with open(file_path, "w") as f:
    f.write(c)
EOF
    bullet "Updated variables.lua with customized apps, geometry, and styling"

    # 2. Update gestures.lua
    if [ -f "$DOTS/config/hypr/hyprland/gestures.lua" ]; then
        sed -i -E "s/workspace_swipe_distance\s*=\s*[0-9]+/workspace_swipe_distance                 = $selected_distance/" "$DOTS/config/hypr/hyprland/gestures.lua" 2>/dev/null || true
        bullet "Updated gestures.lua with swipe distance: ${selected_distance}px"
    fi

    # 3. Update input.lua
    python3 - <<EOF
import re

file_path = "$DOTS/config/hypr/hyprland/input.lua"
with open(file_path, "r") as f:
    c = f.read()

replacements = [
    (r'natural_scroll\s*=\s*(true|false)', 'natural_scroll       = $natural_scroll'),
    (r'tap_to_click\s*=\s*(true|false)', 'tap_to_click         = $tap_click'),
    (r'disable_while_typing\s*=\s*(true|false)', 'disable_while_typing = $disable_typing'),
]

for pat, repl in replacements:
    c = re.sub(pat, repl, c)

with open(file_path, "w") as f:
    f.write(c)
EOF
    bullet "Updated input.lua with natural scroll ($natural_scroll) & tap-to-click ($tap_click)"

    # 4. Update display scale in hyprland.lua, user.lua and rules.json
    if [ -n "$selected_scale" ] && [ "$selected_scale" != "auto" ]; then
        sed -i -E "s/scale\s*=\s*[^,)}]+/scale = $selected_scale/" "$DOTS/config/hypr/hyprland.lua" 2>/dev/null || true
        sed -i -E "s/scale\s*=\s*[^,)}]+/scale = $selected_scale/" "$DOTS/config/hypr/user.lua" 2>/dev/null || true
        bullet "Configured display scaling to ${selected_scale}x native"
    fi

    # 5. Update kitty.conf
    if [ -f "$DOTS/config/kitty/kitty.conf" ]; then
        sed -i -E "s/^font_family\s+.*/font_family      $font_family/" "$DOTS/config/kitty/kitty.conf" 2>/dev/null || true
        sed -i -E "s/^font_size\s+[0-9.]+/font_size $font_size/" "$DOTS/config/kitty/kitty.conf" 2>/dev/null || true
        sed -i -E "s/^shell\s+.*/shell $pref_shell/" "$DOTS/config/kitty/kitty.conf" 2>/dev/null || true
        bullet "Configured Kitty terminal: $font_family @ ${font_size}pt ($pref_shell shell)"
    fi

    # 6. Update rules.json and ~/.config/demonshot/rules.json via Python
    python3 - <<EOF
import json, os

rules_file = "$DOTS/rules.json"
live_rules = os.path.expanduser("~/.config/demonshot/rules.json")

def update_rules(path):
    if not os.path.exists(path):
        return
    try:
        with open(path, "r") as f:
            data = json.load(f)
        data["palette"] = int("$palette_idx")
        data["rounding"] = int("$rounding_val")
        data["gapsIn"] = int("$gaps_in")
        data["gapsOut"] = int("$gaps_out")
        data["blur"] = ($blur_val.lower() == "true")
        data["shadow"] = ($shadow_val.lower() == "true")
        data["natural"] = ($natural_scroll.lower() == "true")
        data["tap"] = ($tap_click.lower() == "true")
        data["typingOff"] = ($disable_typing.lower() == "true")
        if "$selected_scale" and "$selected_scale" != "auto":
            data["monScale"] = float("$selected_scale")
        with open(path, "w") as f:
            json.dump(data, f, indent=4)
    except Exception as e:
        print("Warning updating rules.json:", e)

update_rules(rules_file)
update_rules(live_rules)
EOF
    bullet "Updated house rules palette ($palette_idx) and compositor constraints"

    # 7. Update state/glyph.json and ~/.local/state/rice/glyph.json
    python3 - <<EOF
import json, os

glyph_file = "$DOTS/state/glyph.json"
live_glyph = os.path.expanduser("~/.local/state/rice/glyph.json")

def update_glyph(path):
    if not os.path.exists(path):
        return
    try:
        with open(path, "r") as f:
            data = json.load(f)
        if "$user_name":
            data["name"] = "$user_name"
        data["clock24"] = ($clock_24.lower() == "true")
        data["stars"] = ($stars_val.lower() == "true")
        data["grid"] = ($grid_val.lower() == "true")
        data["rounding"] = int("$rounding_val")
        with open(path, "w") as f:
            json.dump(data, f, indent=4)
    except Exception as e:
        print("Warning updating glyph.json:", e)

update_glyph(glyph_file)
update_glyph(live_glyph)
EOF
    bullet "Updated Nothing OS UI state: User '$user_name', 24h: $clock_24, Stars: $stars_val"

    # 8. Moon Telemetry Pill placement
    local pill_y=865
    [ "$moon_pos" = "centered" ] && pill_y=795
    python3 - <<EOF
import re, os

home_qml = "$DOTS/config/quickshell/glyph/home/Home.qml"
if os.path.exists(home_qml):
    with open(home_qml, "r") as f:
        c = f.read()

    # 1. Surgical update: ONLY target the moonTelemetryBadge y: position
    c = re.sub(
        r'(id:\s*moonTelemetryBadge[^\n]*\n\s*anchors\.horizontalCenter:[^\n]*\n\s*y:\s*)[0-9]+',
        r'\g<1>$pill_y',
        c
    )

    # 2. Self-healing check: ensure core layout positions were never corrupted
    c = re.sub(r'(id:\s*clockArea[^\n]*\n\s*x:\s*80\s*\n\s*y:\s*)[0-9]+', r'\g<1>140', c)
    c = re.sub(r'(\/\/\s*Date line[^\n]*\n\s*Lb\s*\{\s*\n\s*x:\s*88\s*\n\s*y:\s*)[0-9]+', r'\g<1>338', c)
    c = re.sub(r'(\/\/\s*Greeting[^\n]*\n\s*Item\s*\{\s*\n\s*x:\s*86\s*\n\s*y:\s*)[0-9]+', r'\g<1>390', c)
    c = re.sub(r'(\/\/\s*Meta info row[^\n]*\n\s*Row\s*\{\s*\n\s*x:\s*88\s*\n\s*y:\s*)[0-9]+', r'\g<1>530', c)
    c = re.sub(r'(Image\s*\{\s*\n\s*x:\s*885;\s*y:\s*)[0-9]+', r'\g<1>160', c)
    c = re.sub(r'(x:\s*760;\s*y:\s*)[0-9]+(\s*\n\s*width:\s*400[^\n]*\n\s*horizontalAlignment:[^\n]*\n\s*text:\s*root\.nakshatraEnStr)', r'\g<1>258\g<2>', c)
    c = re.sub(r'(x:\s*760;\s*y:\s*)[0-9]+(\s*\n\s*width:\s*400[^\n]*\n\s*horizontalAlignment:[^\n]*\n\s*text:\s*root\.nakshatraHiStr)', r'\g<1>280\g<2>', c)
    c = re.sub(r'opacity:\s*[0-9]+\.85', r'opacity: 0.85', c)
    c = re.sub(r'opacity:\s*[0-9]+\.60', r'opacity: 0.60', c)
    c = re.sub(r'out\.push\(\{\s*id,\s*x:\s*1230\s*\+\s*c\s*\*\s*240,\s*y:\s*[0-9]+\s*\+\s*r\s*\*\s*240\s*\}\);', r'out.push({ id, x: 1230 + c * 240, y: 130 + r * 240 });', c)
    c = re.sub(r'Controls\s*\{\s*size:\s*22;\s*play:\s*[0-9]+\s*\}', r'Controls { size: 22; play: 52 }', c)
    c = re.sub(r'AnimatedImage\s*\{\s*id:\s*cat;\s*anchors\.fill:\s*fx;\s*opacity:\s*[0-9]+;', r'AnimatedImage { id: cat; anchors.fill: fx; opacity: 0;', c)

    with open(home_qml, "w") as f:
        f.write(c)
EOF
    bullet "Configured lunar telemetry badge vertical placement (y: ${pill_y})"

    success "All customized preferences successfully configured."
}

# ── Master Interactive Wizard ─────────────────────────────────────────────────
run_interactive_wizard() {
    print_banner

    # ── Pre-flight Hardware & Environment Probing ─────────────────────────────
    local distro_info; distro_info=$(detect_os)
    local distro_family; distro_family=$(echo "$distro_info" | cut -d'|' -f1)
    local distro_pretty; distro_pretty=$(echo "$distro_info" | cut -d'|' -f2)

    local chassis_info; chassis_info=$(detect_chassis_and_battery)
    local is_laptop_hw; is_laptop_hw=$(echo "$chassis_info" | cut -d'|' -f1)
    local chassis_type; chassis_type=$(echo "$chassis_info" | cut -d'|' -f2)
    local battery_stat; battery_stat=$(echo "$chassis_info" | cut -d'|' -f3)

    local gpu_name; gpu_name=$(detect_gpu)

    local hypr_info; hypr_info=$(detect_hyprland_setup)
    local hypr_status; hypr_status=$(echo "$hypr_info" | cut -d'|' -f1)
    local hypr_type; hypr_type=$(echo "$hypr_info" | cut -d'|' -f2)
    local hypr_lines; hypr_lines=$(echo "$hypr_info" | cut -d'|' -f3)
    local hypr_running; hypr_running=$(echo "$hypr_info" | cut -d'|' -f4)

    local disp_info; disp_info=$(detect_display_info)
    local mon_name; mon_name=$(echo "$disp_info" | cut -d'|' -f1)
    local mon_res; mon_res=$(echo "$disp_info" | cut -d'|' -f2)
    local mon_hz; mon_hz=$(echo "$disp_info" | cut -d'|' -f3)
    local mon_scale; mon_scale=$(echo "$disp_info" | cut -d'|' -f4)
    local mon_count; mon_count=$(echo "$disp_info" | cut -d'|' -f5)

    local touch_dev; touch_dev=$(detect_touchpad_device)

    local default_apps; default_apps=$(detect_installed_apps)
    local def_term; def_term=$(echo "$default_apps" | cut -d'|' -f1)
    local def_browser; def_browser=$(echo "$default_apps" | cut -d'|' -f2)
    local def_fm; def_fm=$(echo "$default_apps" | cut -d'|' -f3)

    box_header "Pre-flight Hardware & Environment Diagnostics"
    bullet "Distribution:       ${BOLD}$distro_pretty${NC} (${CYAN}$distro_family${NC} family)"
    bullet "Hardware Form:      ${BOLD}$chassis_type${NC} (Battery: ${GREEN}$battery_stat${NC})"
    bullet "Graphics Adapter:   ${BOLD}$gpu_name${NC}"
    bullet "Active Displays:    ${BOLD}$mon_name${NC} ($mon_res @ $mon_hz, scale: ${CYAN}$mon_scale${NC}, monitors: $mon_count)"
    bullet "Pointer Input:      ${BOLD}$touch_dev${NC}"
    if [ "$hypr_running" -eq 1 ]; then
        bullet "Compositor:         ${BOLD}Hyprland is RUNNING (Wayland session)${NC}"
    else
        bullet "Compositor:         ${YELLOW}Hyprland not currently running${NC} (Running in TTY / Shell)"
    fi
    if [ "$hypr_status" != "none" ]; then
        bullet "Existing Config:    Found ${BOLD}~/.config/hypr${NC} (format: ${CYAN}$hypr_type${NC}, ${hypr_lines} lines)"
    else
        bullet "Existing Config:    Clean setup (No previous ~/.config/hypr detected)"
    fi

    # ── Initial Confirmation & Immediate Snapshot Backup ─────────────────────
    box_header "Initial Confirmation" "Please verify before proceeding"
    if ! prompt_yes_no "Are you sure you want to continue this ricing?" "Y"; then
        echo ""
        info "Ricing cancelled by user. No changes were made to your system."
        exit 0
    fi

    # Freeze compositor auto-reload so intermediate file writes don't flicker/flash the display
    freeze_compositor

    # Right after user confirms, start making complete backup of their PC's setup!
    echo ""
    backup_desktop

    # ── Step 1: Installation Strategy ─────────────────────────────────────────
    step_head "1" "Installation & Architecture Mode" "Choose how you want to deploy Nothing OS on your machine"
    printf "  ${BOLD}1${NC}) ${WHITE}Full Standalone Glyph Rice${NC} (Clean, unified Nothing OS desktop · Recommended)\n"
    printf "  ${BOLD}2${NC}) ${WHITE}Modular Coexistence Overlay${NC} (Keep your existing Hyprland config & add Glyph widgets)\n"
    printf "  ${BOLD}3${NC}) ${WHITE}Developer Symlink Mode${NC} (Symlinks directly to this repository for live hacking)\n"

    local default_mode="1"
    [ "$hypr_status" = "directory" ] && [ "$hypr_lines" -gt 50 ] && default_mode="2"
    local mode_choice; mode_choice=$(prompt_choice "Select installation mode" "$default_mode" 3)

    # ── Step 2: Hardware Profile ──────────────────────────────────────────────
    step_head "2" "Hardware Profile & Chassis Tuning" "Auto-detected: $chassis_type"
    local default_prof="1"
    [ "$is_laptop_hw" -eq 0 ] && default_prof="2"
    printf "  ${BOLD}1${NC}) Laptop Profile (Enables battery telemetry, low-power alerts, trackpad gestures, backlight OSD)\n"
    printf "  ${BOLD}2${NC}) Desktop PC Profile (Suppresses battery & backlight widgets cleanly; focuses on multi-monitor & mouse)\n"
    local prof_choice; prof_choice=$(prompt_choice "Confirm hardware profile" "$default_prof" 2)

    local is_laptop=1
    [ "$prof_choice" -eq 2 ] && is_laptop=0

    # ── Step 3: Package Management ────────────────────────────────────────────
    install_packages_interactive "$distro_family" "$distro_pretty"

    # ── Step 4: Display Resolution & Scaling Safeguard ────────────────────────
    step_head "4" "Display Scaling & Resolution Safeguard" "Detected: $mon_name ($mon_res @ $mon_hz)"
    info "Note: 1.0x native scale prevents applications from appearing blown up or oversized on 1080p/1200p."
    printf "  ${BOLD}1${NC}) 1.0x  (100%% Native Resolution · Sharp 1:1 pixel mapping · Recommended)\n"
    printf "  ${BOLD}2${NC}) 1.25x (125%% Balanced Scaling · Ideal for 1440p / 2K)\n"
    printf "  ${BOLD}3${NC}) 1.5x  (150%% High Scaling)\n"
    printf "  ${BOLD}4${NC}) 2.0x  (200%% HiDPI Integer Scaling · Ideal for 4K)\n"
    printf "  ${BOLD}5${NC}) Auto  (Let Hyprland choose dynamically)\n"
    printf "  ${BOLD}6${NC}) Custom scale factor\n"
    printf "  ${BOLD}7${NC}) Keep existing monitor configuration untouched\n"
    local scale_choice; scale_choice=$(prompt_choice "Select display scale factor" "1" 7)
    local selected_scale="1.0"
    case "$scale_choice" in
        1) selected_scale="1.0" ;;
        2) selected_scale="1.25" ;;
        3) selected_scale="1.5" ;;
        4) selected_scale="2.0" ;;
        5) selected_scale="auto" ;;
        6) selected_scale=$(prompt_text "Enter custom scale (e.g. 1.15)" "1.15") ;;
        7) selected_scale="" ;;
    esac

    # ── Step 5: Visual Theme & Styling ────────────────────────────────────────
    step_head "5" "Visual Styling & Desktop Aesthetics" "Customise Nothing OS appearance and window geometry"
    printf "  ${BOLD}1${NC}) Nothing OS Signature (Monochrome White with Crimson Red accents · Iconic Nothing)\n"
    printf "  ${BOLD}2${NC}) Ghost Monochrome (Pure Black & White only · Zero color accents · Ultra minimal)\n"
    printf "  ${BOLD}3${NC}) Holy Water (Ice Blue / Cyan accents · Cool & pristine)\n"
    printf "  ${BOLD}4${NC}) Gilded Gold (Warm Amber / Gold accents · Regal & warm)\n"
    printf "  ${BOLD}5${NC}) Nightshade (Violet / Deep Purple accents)\n"
    printf "  ${BOLD}6${NC}) Absinthe (Emerald / Toxic Green accents)\n"
    local theme_choice; theme_choice=$(prompt_choice "Select Color Palette" "1" 6)
    local pal_choice=0
    case "$theme_choice" in
        1) pal_choice=0 ;; # Demon's Shot
        2) pal_choice=6 ;; # Ghost
        3) pal_choice=3 ;; # Holy Water
        4) pal_choice=5 ;; # Gilded
        5) pal_choice=2 ;; # Nightshade
        6) pal_choice=1 ;; # Absinthe
    esac

    echo ""
    info "Window Corner Rounding:"
    printf "  ${BOLD}1${NC}) 0px  (Sharp Flat Retro · Crisp minimalist window borders · Recommended)\n"
    printf "  ${BOLD}2${NC}) 8px  (Nothing OS Subtle · Modern rounded corners)\n"
    printf "  ${BOLD}3${NC}) 14px (Soft Curved · Pill aesthetic)\n"
    printf "  ${BOLD}4${NC}) Custom radius\n"
    local round_choice; round_choice=$(prompt_choice "Select window corner rounding" "1" 4)
    local selected_rounding=0
    case "$round_choice" in
        1) selected_rounding=0 ;;
        2) selected_rounding=8 ;;
        3) selected_rounding=14 ;;
        4) selected_rounding=$(prompt_text "Enter corner radius in pixels" "12") ;;
    esac

    echo ""
    info "Window Gaps & Spacing:"
    printf "  ${BOLD}1${NC}) Balanced (Inner: 6px, Outer: 14px · Nothing OS signature layout · Recommended)\n"
    printf "  ${BOLD}2${NC}) Compact  (Inner: 3px, Outer: 6px · High screen efficiency)\n"
    printf "  ${BOLD}3${NC}) Gapless  (Inner: 0px, Outer: 0px · Maximum real estate)\n"
    printf "  ${BOLD}4${NC}) Custom gaps\n"
    local gaps_choice; gaps_choice=$(prompt_choice "Select window gaps" "1" 4)
    local sel_gaps_in=6 sel_gaps_out=14
    case "$gaps_choice" in
        1) sel_gaps_in=6; sel_gaps_out=14 ;;
        2) sel_gaps_in=3; sel_gaps_out=6 ;;
        3) sel_gaps_in=0; sel_gaps_out=0 ;;
        4)
            sel_gaps_in=$(prompt_text "Inner window gaps (px)" "6")
            sel_gaps_out=$(prompt_text "Outer workspace gaps (px)" "14")
            ;;
    esac

    echo ""
    local enable_stars="true"
    prompt_yes_no "Enable animated starfield particle effect on Altar background?" "Y" || enable_stars="false"

    local enable_grid="true"
    prompt_yes_no "Enable subtle dot-matrix background grid?" "Y" || enable_grid="false"

    local enable_blur="true"
    prompt_yes_no "Enable backdrop blur and window glow shadows?" "Y" || enable_blur="false"

    # ── Step 6: Input Devices & Gestures ──────────────────────────────────────
    step_head "6" "Input Devices, Trackpad & Mouse" "Pointer Device: $touch_dev"
    local selected_distance=250
    local sel_natural="true"
    local sel_tap="true"
    local sel_typing_off="false"

    if [ "$is_laptop" -eq 1 ]; then
        info "Calibrated 1:1 Workspace Swipe Distance:"
        printf "  ${BOLD}1${NC}) 250px (Calibrated Natural Travel · Effortless 1:1 swipe · Recommended)\n"
        printf "  ${BOLD}2${NC}) 200px (Shorter travel · Ultra-fast workspace flip)\n"
        printf "  ${BOLD}3${NC}) 350px (Deliberate medium travel)\n"
        printf "  ${BOLD}4${NC}) 500px (Long travel)\n"
        printf "  ${BOLD}5${NC}) Custom pixel value\n"
        local dist_choice; dist_choice=$(prompt_choice "Select workspace swipe travel distance" "1" 5)
        case "$dist_choice" in
            1) selected_distance=250 ;;
            2) selected_distance=200 ;;
            3) selected_distance=350 ;;
            4) selected_distance=500 ;;
            5) selected_distance=$(prompt_text "Enter custom distance in pixels" "250") ;;
        esac

        prompt_yes_no "Enable Natural Scrolling (Inverted / macOS style direction)?" "Y" || sel_natural="false"
        prompt_yes_no "Enable Tap-to-Click on touchpad?" "Y" || sel_tap="false"
        prompt_yes_no "Disable touchpad while typing?" "N" && sel_typing_off="true"
    else
        info "Desktop PC Profile: Trackpad gestures dormant. Standard mouse controls active."
    fi

    echo ""
    info "Cursor Theme & Size:"
    printf "  ${BOLD}1${NC}) Bibata-Modern-Ice (White crisp minimalist cursor · Recommended)\n"
    printf "  ${BOLD}2${NC}) Bibata-Modern-Classic (Black cursor)\n"
    printf "  ${BOLD}3${NC}) Adwaita (Default GNOME / Wayland cursor)\n"
    local cur_choice; cur_choice=$(prompt_choice "Select cursor theme" "1" 3)
    local sel_cursor="Bibata-Modern-Ice"
    case "$cur_choice" in
        1) sel_cursor="Bibata-Modern-Ice" ;;
        2) sel_cursor="Bibata-Modern-Classic" ;;
        3) sel_cursor="Adwaita" ;;
    esac

    local sel_cursor_size; sel_cursor_size=$(prompt_text "Cursor size in pixels (20, 24, 28, 32)" "24")

    # ── Step 7: Default Applications ──────────────────────────────────────────
    step_head "7" "Default Applications & Shell Stack" "Installed: Term: $def_term · Browser: $def_browser · FM: $def_fm"
    local pref_term; pref_term=$(prompt_text "Default Terminal Emulator" "$def_term")
    local pref_browser; pref_browser=$(prompt_text "Default Web Browser" "$def_browser")
    local pref_fm; pref_fm=$(prompt_text "Default File Manager" "$def_fm")
    local pref_shell; pref_shell=$(prompt_text "Default Shell (fish/zsh/bash)" "fish")

    # ── Step 8: Typography & Terminal Font ────────────────────────────────────
    step_head "8" "Typography & Terminal Font" "Customise terminal typography"
    printf "  ${BOLD}1${NC}) JetBrains Mono Nerd Font (Included in rice · Recommended)\n"
    printf "  ${BOLD}2${NC}) Fira Code Nerd Font\n"
    printf "  ${BOLD}3${NC}) Cascadia Code Nerd Font\n"
    printf "  ${BOLD}4${NC}) Custom font name\n"
    local font_choice; font_choice=$(prompt_choice "Select terminal font family" "1" 4)
    local sel_font="JetBrainsMono Nerd Font"
    case "$font_choice" in
        1) sel_font="JetBrainsMono Nerd Font" ;;
        2) sel_font="FiraCode Nerd Font" ;;
        3) sel_font="CaskaydiaCove Nerd Font" ;;
        4) sel_font=$(prompt_text "Enter font family name" "JetBrainsMono Nerd Font") ;;
    esac

    echo ""
    printf "  ${BOLD}1${NC}) 12.5 pt (Optimal clarity and proportions · Recommended)\n"
    printf "  ${BOLD}2${NC}) 11.0 pt (Compact)\n"
    printf "  ${BOLD}3${NC}) 14.0 pt (Large)\n"
    printf "  ${BOLD}4${NC}) Custom font size\n"
    local size_choice; size_choice=$(prompt_choice "Select terminal font size" "1" 4)
    local sel_font_size="12.5"
    case "$size_choice" in
        1) sel_font_size="12.5" ;;
        2) sel_font_size="11.0" ;;
        3) sel_font_size="14.0" ;;
        4) sel_font_size=$(prompt_text "Enter font size in points" "12.5") ;;
    esac

    # ── Step 9: Astronomical Engine & Moon Telemetry ──────────────────────────
    step_head "9" "Astronomical Engine & Moon Telemetry" "Real-time lunar phase, nakshatra & tithi calculations via Swiss Ephemeris"
    printf "  ${BOLD}1${NC}) Lowered Telemetry Pill (Spaced 100px beneath lunar orb for clean margin · Recommended)\n"
    printf "  ${BOLD}2${NC}) Compact Centered Telemetry Pill (Directly beneath globe rim)\n"
    local moon_pill_choice; moon_pill_choice=$(prompt_choice "Select moon telemetry badge placement" "1" 2)
    local sel_moon_pos="lowered"
    [ "$moon_pill_choice" -eq 2 ] && sel_moon_pos="centered"

    # ── Step 10: User Identity & Clock ────────────────────────────────────────
    step_head "10" "User Identity & Clock Preferences" "Personalise greetings and time display"
    local default_name="${USER^}"
    [ -f "$HOME/.local/state/rice/glyph.json" ] && default_name=$(jq -r '.name // empty' "$HOME/.local/state/rice/glyph.json" 2>/dev/null || echo "${USER^}")
    local user_name; user_name=$(prompt_text "Display name for Altar & Lockscreen greeting" "${default_name:-Vaishno}")

    echo ""
    printf "  ${BOLD}1${NC}) 12-Hour Format with AM/PM indicator (e.g. 11:30 PM · Recommended)\n"
    printf "  ${BOLD}2${NC}) 24-Hour Military Format (e.g. 23:30)\n"
    local clock_choice; clock_choice=$(prompt_choice "Select clock format" "1" 2)
    local sel_clock24="false"
    [ "$clock_choice" -eq 2 ] && sel_clock24="true"

    # ── Step 11: System Services & Integration ────────────────────────────────
    step_head "11" "System Services & Polish" "Optional system daemons and desktop integration"
    local enable_timer="true"
    prompt_yes_no "Enable Nakshatra astronomical timer service (auto-updates daily at midnight)?" "Y" || enable_timer="false"

    local enable_gtk_dark="true"
    prompt_yes_no "Enforce system-wide GTK prefer-dark color scheme and dark theme?" "Y" || enable_gtk_dark="false"

    # ── Step 12: Automated Deployment & Application ───────────────────────────
    box_header "Deploying Configuration" "All customizations collected! Applying changes automatically..."

    setup_python_env

    apply_user_customizations \
        "$pref_term" "$pref_browser" "$pref_fm" "$pref_shell" \
        "$selected_scale" "$selected_distance" "$pal_choice" \
        "$selected_rounding" "$sel_gaps_in" "$sel_gaps_out" \
        "$enable_blur" "$enable_blur" "$sel_natural" "$sel_tap" "$sel_typing_off" \
        "$sel_cursor" "$sel_cursor_size" "$sel_font" "$sel_font_size" \
        "$user_name" "$sel_clock24" "$enable_stars" "$enable_grid" "$sel_moon_pos"

    case "$mode_choice" in
        1) deploy_standalone false ;;
        2) deploy_overlay ;;
        3) deploy_standalone true ;;
    esac

    # GTK dark mode
    if [ "$enable_gtk_dark" = "true" ] && command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark 2>/dev/null || true
    fi

    # Nakshatra service
    if [ "$enable_timer" = "true" ] && command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user enable --now nakshatra-calc.timer 2>/dev/null || true
    fi

    # Single smooth atomic reload (zero flashing during install)
    unfreeze_and_atomic_reload "$selected_scale" "$mon_scale"

    # ── Step 13: Post-Install Summary & Cheat Sheet ───────────────────────────
    print_banner
    success "Nothing OS Glyph Rice has been successfully installed and configured!"
    printf "\n"
    box_header "Quick Reference Cheat Sheet"
    bullet "<Super> (tap)         Open Application Launcher"
    bullet "<Super> + Space       Toggle Bottom Altar Dashboard"
    bullet "<Super> + A           Quick Settings Control Center"
    bullet "<Super> + I           Preferences & Configuration"
    bullet "<Super> + Return      Open Terminal ($pref_term)"
    bullet "<Super> + B           Open Web Browser ($pref_browser)"
    bullet "<Super> + Q           Close Active Window"
    bullet "<Super> + V           Clipboard History"
    bullet "<Super> + Period      Emoji & Symbols Palette"
    if [ "$is_laptop" -eq 1 ]; then
        bullet "3-Finger Swipe ↔     1:1 Workspace Switching (${selected_distance}px travel)"
        bullet "3-Finger Swipe ↑/↓    Launcher / Altar Dashboard"
        bullet "3-Finger Pinch In/Out Terminal ($pref_term) / Browser ($pref_browser)"
        bullet "4-Finger Pinch In/Out File Manager ($pref_fm) / Settings"
    else
        bullet "<Super> + LMB Drag   Move floating window"
        bullet "<Super> + RMB Drag   Resize floating window"
        bullet "<Super> + Scroll     Switch workspaces"
    fi
    printf "\n"
    info "Rollback Protection: If you ever want to revert, run: ./restore.sh"
    printf "\n"

    if [ "$hypr_running" -eq 1 ]; then
        if prompt_yes_no "Would you like to test open the Altar dashboard now?" "Y"; then
            hyprctl dispatch global shell:altar >/dev/null 2>&1 || true
        fi
    fi
}

# ── CLI Command-Line Options ──────────────────────────────────────────────────
show_help() {
    cat <<EOF
⬤ Nothing OS Glyph Rice — Universal Dynamic Installer

Usage:
  ./install.sh [OPTIONS]

Options:
  (no args)        Launch interactive step-by-step TUI configuration wizard
  --menu           Force interactive menu-driven mode (same as default)
  --quick          Quick automated setup with recommended defaults
  --links          Developer symlink mode (links to repo for live git editing)
  --overlay        Modular overlay mode (coexist with existing Hyprland setup)
  --backup-only    Create a snapshot backup of your current desktop and exit
  --restore [DIR]  Revert desktop to previous backup snapshot
  --help, -h       Display this help guide

Rollback & Safety:
  A full backup snapshot is automatically created before any changes are made.
  You can restore your desktop anytime with 1 command:
    ./restore.sh
EOF
}

# ── Main Entrypoint ───────────────────────────────────────────────────────────
[ "${EUID:-$(id -u)}" -eq 0 ] && { error "Please run as your normal user, not as root (sudo will be invoked if needed)."; exit 1; }

ACTION="${1:-}"

case "$ACTION" in
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
        freeze_compositor
        backup_desktop
        setup_python_env
        deploy_standalone true
        unfreeze_and_atomic_reload "" ""
        success "Installation completed in symlink mode!"
        ;;
    --overlay)
        freeze_compositor
        backup_desktop
        setup_python_env
        deploy_overlay
        unfreeze_and_atomic_reload "" ""
        success "Installation completed in overlay mode!"
        ;;
    --quick)
        freeze_compositor
        backup_desktop
        local_distro=$(detect_os | cut -d'|' -f1)
        local_pretty=$(detect_os | cut -d'|' -f2)
        install_packages_interactive "$local_distro" "$local_pretty" <<< "1"
        setup_python_env
        deploy_standalone true
        unfreeze_and_atomic_reload "" ""
        success "Quick installation completed with recommended defaults!"
        ;;
    ""|--menu)
        run_interactive_wizard
        ;;
    *)
        error "Unknown option: $ACTION (run './install.sh --help' for usage)"
        ;;
esac
