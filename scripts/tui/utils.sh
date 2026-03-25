#!/bin/bash
set -euo pipefail
# TUI utility functions — dialog/whiptail wrappers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

# Detect available dialog tool
if command -v dialog >/dev/null 2>&1; then
    DIALOG=dialog
elif command -v whiptail >/dev/null 2>&1; then
    DIALOG=whiptail
else
    log_fatal "Neither 'dialog' nor 'whiptail' found. Install one of them."
fi

DIALOG_HEIGHT=20
DIALOG_WIDTH=60
DIALOG_LIST_HEIGHT=10
DIALOG_TITLE="Linux Lab"

# Show a menu and return the selected item
tui_menu() {
    local title="$1"
    shift
    # Remaining args are tag/item pairs
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --menu "" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "$@" 3>&1 1>&2 2>&3
}

# Show a yes/no dialog
tui_yesno() {
    local message="$1"
    $DIALOG --clear --title "$DIALOG_TITLE" \
        --yesno "$message" $DIALOG_HEIGHT $DIALOG_WIDTH 3>&1 1>&2 2>&3
}

# Show an input box
tui_input() {
    local title="$1"
    local default="${2:-}"
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --inputbox "" $DIALOG_HEIGHT $DIALOG_WIDTH "$default" 3>&1 1>&2 2>&3
}

# Show a checklist (multi-select)
tui_checklist() {
    local title="$1"
    shift
    # Remaining args are tag/item/status triples
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --checklist "" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "$@" 3>&1 1>&2 2>&3
}

# Show a message box
tui_message() {
    local message="$1"
    $DIALOG --clear --title "$DIALOG_TITLE" \
        --msgbox "$message" $DIALOG_HEIGHT $DIALOG_WIDTH
}
