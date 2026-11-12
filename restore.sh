#!/usr/bin/env bash
# ==============================================================================
# Ricing Rollback / Restore Script
# Restores your previous Hyprland & Desktop configuration from a backup snapshot.
# Works across all shells (Bash, Fish, Zsh).
# ==============================================================================

set -euo pipefail

# Colors & Logging
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
error()   { printf "${RED}✖${NC} %s\n" "$*"; exit 1; }

BACKUP_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/ricing-backups"

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
    if [ -L "$BACKUP_ROOT/latest" ] && [ -d "$BACKUP_ROOT/latest" ]; then
        TARGET_BACKUP="$(cd "$BACKUP_ROOT/latest" && pwd)"
    else
        # Find latest directory if symlink is missing
        LATEST_DIR=$(find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r | head -n 1 || true)
        if [ -n "$LATEST_DIR" ] && [ -d "$LATEST_DIR" ]; then
            TARGET_BACKUP="$LATEST_DIR"
        fi
    fi
fi

if [ -z "$TARGET_BACKUP" ] || [ ! -d "$TARGET_BACKUP" ]; then
    # Also check legacy ~/.dots-backup-* folders
    LEGACY_BACKUP=$(find "$HOME" -maxdepth 1 -name ".dots-backup-*" -type d 2>/dev/null | sort -r | head -n 1 || true)
    if [ -n "$LEGACY_BACKUP" ]; then
        warn "No standard backup found in $BACKUP_ROOT, but found legacy backup: $LEGACY_BACKUP"
        TARGET_BACKUP="$LEGACY_BACKUP"
    else
        error "No backups found to restore from! Looked in $BACKUP_ROOT"
    fi
fi

say "Starting desktop configuration rollback..."
info "Selected backup: ${BOLD}$TARGET_BACKUP${NC}"

# Check for manifest
MANIFEST="$TARGET_BACKUP/manifest.txt"
if [ -f "$MANIFEST" ]; then
    info "Found backup manifest: processing tracked entries..."
    while IFS='|' read -r TYPE REL_PATH IS_LINK LINK_TARGET; do
        # Ignore comments or empty lines
        [[ "$TYPE" =~ ^#.*$ ]] && continue
        [ -z "$REL_PATH" ] && continue

        DEST="$HOME/$REL_PATH"
        BACKUP_SRC="$TARGET_BACKUP/data/$REL_PATH"

        # Remove current active ricing symlink or file
        if [ -L "$DEST" ] || [ -e "$DEST" ]; then
            rm -rf "$DEST"
        fi

        # Restore original
        if [ "$IS_LINK" = "1" ] && [ -n "$LINK_TARGET" ]; then
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
    # Generic recursive restore for directories inside backup
    info "No manifest file found; performing directory tree restore..."
    (
        cd "$TARGET_BACKUP"
        # If data/ subdir exists, restore from there; otherwise from root of backup
        SRC_BASE="$TARGET_BACKUP"
        [ -d "$TARGET_BACKUP/data" ] && SRC_BASE="$TARGET_BACKUP/data"

        cd "$SRC_BASE"
        find . -mindepth 1 -maxdepth 3 | while read -r item; do
            REL="${item#./}"
            # skip metadata files
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
info "If you need to re-apply the custom ricing at any time, run: ./install.sh"
