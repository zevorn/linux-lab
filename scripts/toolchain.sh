#!/bin/bash
# Toolchain version resolution and wrapper management
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:-info}"

toolchain_info() {
    log_info "Toolchain configuration:"
    echo "  Board arch:    $BOARD_ARCH"
    echo "  Cross compile: $CROSS_COMPILE"
    echo "  Version:       ${TOOLCHAIN_VERSION:-system}"
    echo "  Type:          ${TOOLCHAIN_TYPE:-dynamic}"

    local tc_bin="${TOOLCHAIN_BIN:-}"
    if [ -n "$tc_bin" ] && [ -d "$tc_bin" ]; then
        echo "  Path:          $tc_bin"
        local gcc="${tc_bin}/${CROSS_COMPILE}gcc"
        if [ -x "$gcc" ]; then
            echo "  GCC version:   $("$gcc" --version | head -1)"
        fi
    elif [ "$BOARD_ARCH" = "x86_64" ]; then
        echo "  Path:          (using host gcc)"
        echo "  GCC version:   $(gcc --version | head -1)"
    else
        echo "  Path:          (not found — will search PATH)"
        if command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
            echo "  GCC version:   $("${CROSS_COMPILE}gcc" --version | head -1)"
        else
            log_warn "${CROSS_COMPILE}gcc not found in PATH"
        fi
    fi
}

toolchain_check() {
    if [ "$BOARD_ARCH" = "x86_64" ]; then
        check_cmd gcc
        return 0
    fi

    if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
        log_error "Cross compiler not found: ${CROSS_COMPILE}gcc"
        log_info "Install it or set TOOLCHAIN_BASE in .linux-lab.conf"
        return 1
    fi
    log_ok "Toolchain OK: ${CROSS_COMPILE}gcc"
}

case "$ACTION" in
    info)   toolchain_info ;;
    check)  toolchain_check ;;
    *)      log_fatal "Unknown action: $ACTION" ;;
esac
