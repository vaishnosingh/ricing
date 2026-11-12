#!/usr/bin/env fish
# ==============================================================================
# Nothing OS Glyph Rice — Fish wrapper for restore.sh
# ==============================================================================

set -l SCRIPT_DIR (status dirname)
exec bash "$SCRIPT_DIR/restore.sh" $argv
