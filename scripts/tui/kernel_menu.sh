#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

kernel_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Kernel Management" \
            "1" "Download kernel source" \
            "2" "Configure kernel (menuconfig)" \
            "3" "Build kernel" \
            "4" "Apply patches" \
            "5" "Export patches" \
            "6" "Save config fragment" \
            "7" "Clean kernel build" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" kernel-download ;;
            2) make -C "$TOP_DIR" kernel-menuconfig ;;
            3) make -C "$TOP_DIR" kernel-build ;;
            4) make -C "$TOP_DIR" kernel-patch ;;
            5) make -C "$TOP_DIR" kernel-export-patches ;;
            6) make -C "$TOP_DIR" kernel-saveconfig ;;
            7) make -C "$TOP_DIR" kernel-clean ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

kernel_menu
