#!/usr/bin/env fish
# ==============================================================================
# Nothing OS Glyph Rice — Fish wrapper for install.sh
# ==============================================================================

set -l SCRIPT_DIR (status dirname)
exec bash "$SCRIPT_DIR/install.sh" $argv
