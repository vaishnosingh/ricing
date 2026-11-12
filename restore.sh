#!/usr/bin/env bash
# ==============================================================================
# ⬤ Nothing OS Glyph Rice — Interactive Rollback & Restore Script
# Restores previous Hyprland & Desktop configuration from backup snapshots.
# Works across all shells (Bash, Fish, Zsh) on any Linux distribution.
# ==============================================================================

set -euo pipefail

# Colors & Logging
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    BLUE=$'\033[0;34m'
    YELLOW=$'\033[1;33m'
    CYAN=$'\033[0;36m'
    WHITE=$'\033[1;37m'
    BOLD=$'\033[1m'
    DIM=$'\033[2m'
    NC=$'\033[0m'
else
    RED='' GREEN='' BLUE='' YELLOW='' CYAN='' WHITE='' BOLD='' DIM='' NC=''
fi

say()     { printf "${RED}●${NC} %b\n" "$*"; }
info()    { printf "${BLUE}ℹ${NC} %b\n" "$*"; }
success() { printf "${GREEN}✓${NC} ${BOLD}%b${NC}\n" "$*"; }
warn()    { printf "${YELLOW}⚠${NC} %b\n" "$*"; }
error()   { printf "${RED}✖${NC} %b\n" "$*"; exit 1; }
bullet()  { printf "  ${DIM}•${NC} %b\n" "$*"; }

BACKUP_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/ricing-backups"

print_header() {
    printf "\n${BOLD}${CYAN}┌─[ ⬤ Nothing OS Glyph Rice · Desktop Rollback Wizard ]${NC}\n"
    printf "${CYAN}│${NC}  ${DIM}Select a snapshot backup to restore your previous desktop${NC}\n"
    printf "${CYAN}└─────────────────────────────────────────────────────────────────${NC}\n\n"
}

# Determine target backup directory
TARGET_BACKUP=""
if [ -n "${1:-}" ]; then
    if [ -d "$1" ]; then
        TARGET_BACKUP="$(cd "$1" && pwd)"
    elif [ -d "$BACKUP_ROOT/$1" ]; then
        TARGET_BACKUP="$(cd "$BACKUP_ROOT/$1" && pwd)"
    else
        error "Specified backup directory does not exist: $1"
    fi
else
    print_header
    # Scan for available backups
    mapfile -t BACKUPS < <(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -name "backup-*" 2>/dev/null | sort -r || true)

    if [ "${#BACKUPS[@]}" -eq 0 ]; then
        # Check legacy backups
        mapfile -t BACKUPS < <(find "$HOME" -maxdepth 1 -name ".dots-backup-*" -type d 2>/dev/null | sort -r || true)
    fi

    if [ "${#BACKUPS[@]}" -eq 0 ]; then
        error "No backups found to restore from! Looked in $BACKUP_ROOT"
    fi

    if [ "${#BACKUPS[@]}" -eq 1 ]; then
        TARGET_BACKUP="${BACKUPS[0]}"
        info "Found latest backup snapshot: ${BOLD}$(basename "$TARGET_BACKUP")${NC}"
    else
        info "Multiple backup snapshots found:"
        for i in "${!BACKUPS[@]}"; do
            local_bname="$(basename "${BACKUPS[$i]}")"
            local_date=""
            [ -f "${BACKUPS[$i]}/backup_info.txt" ] && local_date="$(grep "Backup Date:" "${BACKUPS[$i]}/backup_info.txt" | cut -d: -f2- | awk '{$1=$1};1')"
            printf "  ${BOLD}%d${NC}) ${WHITE}%s${NC} ${DIM}(%s)${NC}\n" "$((i+1))" "$local_bname" "${local_date:-Snapshot}"
        done
        printf "  ${BOLD}0${NC}) Cancel\n\n"

        while true; do
            printf "${BOLD}Select a backup to restore [1-%d] (Default: 1): ${NC}" "${#BACKUPS[@]}"
            read -r choice || true
            choice="${choice:-1}"
            if [ "$choice" = "0" ]; then
                info "Restore cancelled by user."
                exit 0
            elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#BACKUPS[@]}" ]; then
                TARGET_BACKUP="${BACKUPS[$((choice-1))]}"
                break
            else
                warn "Invalid selection. Please choose between 1 and ${#BACKUPS[@]}."
            fi
        done
    fi
fi

if [ -z "$TARGET_BACKUP" ] || [ ! -d "$TARGET_BACKUP" ]; then
    error "Could not determine a valid backup to restore."
fi

say "Preparing to restore desktop from backup snapshot..."
bullet "Source Backup: ${BOLD}$TARGET_BACKUP${NC}"
echo ""

printf "${BOLD}Are you sure you want to rollback to this snapshot? [Y/n]: ${NC}"
read -r confirm || true
confirm="${confirm:-Y}"
case "$confirm" in
    [yY]|[yY][eE][sS]) ;;
    *) info "Rollback cancelled."; exit 0 ;;
esac

# Check for manifest
MANIFEST="$TARGET_BACKUP/manifest.txt"
if [ -f "$MANIFEST" ]; then
    info "Found backup manifest: processing tracked entries..."
    while IFS='|' read -r TYPE REL_PATH IS_SYMLINK LINK_TARGET || [ -n "$TYPE" ]; do
        [[ "$TYPE" =~ ^#.*$ ]] && continue
        [ -z "$REL_PATH" ] && continue

        DEST="$HOME/$REL_PATH"
        BACKUP_SRC="$TARGET_BACKUP/data/$REL_PATH"

        if [ -L "$DEST" ] || [ -e "$DEST" ]; then
            rm -rf "$DEST"
        fi

        if [ "$IS_SYMLINK" = "1" ] && [ -n "$LINK_TARGET" ]; then
            mkdir -p "$(dirname "$DEST")"
            ln -s "$LINK_TARGET" "$DEST"
            printf "  restored symlink: ~/%s -> %s\n" "$REL_PATH" "$LINK_TARGET"
        elif [ -e "$BACKUP_SRC" ]; then
            mkdir -p "$(dirname "$DEST")"
            cp -a "$BACKUP_SRC" "$DEST"
            printf "  restored: ~/%s\n" "$REL_PATH"
        fi
    done < "$MANIFEST"
else
    info "No manifest file found; performing directory tree restore..."
    (
        cd "$TARGET_BACKUP"
        SRC_BASE="$TARGET_BACKUP"
        [ -d "$TARGET_BACKUP/data" ] && SRC_BASE="$TARGET_BACKUP/data"

        cd "$SRC_BASE"
        find . -mindepth 1 -maxdepth 3 | while read -r item; do
            REL="${item#./}"
            [ "$REL" = "manifest.txt" ] && continue
            [ "$REL" = "backup_info.txt" ] && continue

            DEST="$HOME/$REL"
            if [ -L "$DEST" ] || [ -e "$DEST" ]; then
                rm -rf "$DEST"
            fi
            mkdir -p "$(dirname "$DEST")"
            cp -a "$item" "$DEST"
            printf "  restored: ~/%s\n" "$REL"
        done
    )
fi

# Stop and disable user timer added by ricing
systemctl --user stop nakshatra-calc.timer 2>/dev/null || true
systemctl --user disable nakshatra-calc.timer 2>/dev/null || true

# Rebuild font cache
fc-cache -f >/dev/null 2>&1 || true

# Reload Hyprland if running
if command -v hyprctl >/dev/null 2>&1 && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    info "Reloading Hyprland configuration..."
    hyprctl reload >/dev/null 2>&1 || true
fi

# Restart QuickShell or kill rice daemon if active
if pgrep -x qs >/dev/null 2>&1 || pgrep -x quickshell >/dev/null 2>&1; then
    info "Quickshell was active. Reloading desktop shell..."
    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
fi

echo ""
success "Desktop configuration has been successfully reverted to the state saved in:"
printf "  ${BOLD}%s${NC}\n\n" "$TARGET_BACKUP"
info "To re-apply Nothing OS Glyph Rice at any time, run: ./install.sh"
