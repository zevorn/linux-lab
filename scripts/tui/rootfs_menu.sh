#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

rootfs_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Rootfs Management" \
            "1" "Prepare prebuilt rootfs" \
            "2" "Build rootfs (Buildroot)" \
            "3" "Configure Buildroot (menuconfig)" \
            "4" "Inject kernel modules" \
            "5" "Clean rootfs" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" rootfs-prepare ;;
            2) make -C "$TOP_DIR" rootfs-build ;;
            3) make -C "$TOP_DIR" rootfs-menuconfig ;;
            4) make -C "$TOP_DIR" rootfs-modules ;;
            5) make -C "$TOP_DIR" rootfs-clean ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

rootfs_menu
