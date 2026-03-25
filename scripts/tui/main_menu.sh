#!/bin/bash
set -euo pipefail
# TUI main menu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Main Menu" \
            "1" "Select board and boot" \
            "2" "Kernel management" \
            "3" "Rootfs management" \
            "4" "QEMU management" \
            "5" "Add new board" \
            "6" "System info" \
        ) || break

        case "$choice" in
            1) "$SCRIPT_DIR/board_select.sh" ;;
            2) "$SCRIPT_DIR/kernel_menu.sh" ;;
            3) "$SCRIPT_DIR/rootfs_menu.sh" ;;
            4) "$SCRIPT_DIR/qemu_menu.sh" ;;
            5) "$SCRIPT_DIR/board_create.sh" ;;
            6) tui_message "$(make -C "$TOP_DIR" info 2>&1)" ;;
        esac
    done
    clear
}

main_menu
