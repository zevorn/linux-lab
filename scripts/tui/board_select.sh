#!/bin/bash
set -euo pipefail
# TUI board selection and boot flow
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

select_board() {
    # Step 1: Select architecture
    local archs=()
    for arch_dir in "$BOARDS_DIR"/*/; do
        local arch
        arch=$(basename "$arch_dir")
        archs+=("$arch" "$arch architecture")
    done

    local arch
    arch=$(tui_menu "Select Architecture" "${archs[@]}") || return

    # Step 2: Select board
    local boards=()
    for board_dir in "$BOARDS_DIR/$arch"/*/board.mk; do
        local board
        board=$(dirname "$board_dir" | xargs basename)
        local desc
        desc=$(grep '^BOARD_DESC' "$board_dir" | head -1 | sed 's/.*?=\s*//')
        boards+=("$board" "$desc")
    done

    local board
    board=$(tui_menu "Select Board ($arch)" "${boards[@]}") || return

    local full_board="$arch/$board"

    # Step 3: Select kernel version
    local board_mk="$BOARDS_DIR/$full_board/board.mk"
    local supported
    supported=$(grep '^KERNEL_SUPPORTED' "$board_mk" | head -1 | sed 's/.*?=\s*//')
    local default_kernel
    default_kernel=$(grep '^KERNEL_DEFAULT' "$board_mk" | head -1 | sed 's/.*?=\s*//')

    local kernels=()
    for ver in $supported; do
        if [ "$ver" = "$default_kernel" ]; then
            kernels+=("$ver" "LTS (default)")
        else
            kernels+=("$ver" "LTS")
        fi
    done

    local kernel
    kernel=$(tui_menu "Select Kernel ($full_board)" "${kernels[@]}") || return

    # Step 4: Confirm and boot
    if tui_yesno "Boot $full_board with kernel $kernel?"; then
        clear
        make -C "$TOP_DIR" boot BOARD="$full_board" KERNEL="$kernel"
    fi
}

select_board
