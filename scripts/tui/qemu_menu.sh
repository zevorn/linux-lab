#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

qemu_menu() {
    while true; do
        local choice
        choice=$(tui_menu "QEMU Management" \
            "1" "Build QEMU from source" \
            "2" "Rebuild QEMU (incremental)" \
            "3" "Boot QEMU" \
            "4" "Boot QEMU in debug mode" \
            "5" "Export QEMU patches" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" qemu-build ;;
            2) make -C "$TOP_DIR" qemu-rebuild ;;
            3) make -C "$TOP_DIR" qemu-boot ;;
            4) make -C "$TOP_DIR" qemu-debug ;;
            5) make -C "$TOP_DIR" qemu-export-patches ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

qemu_menu
