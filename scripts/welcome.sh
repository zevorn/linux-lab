#!/bin/bash
# Welcome message for CNB Cloud IDE startup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/cnb-detect.sh"

echo "======================================"
echo "  Welcome to Linux Lab on CNB!"
echo "======================================"
echo ""
echo "  Quick start:"
echo "    make tui                         # TUI interactive mode"
echo "    make boot BOARD=arm/vexpress-a9  # Quick boot ARM board"
echo ""
echo "  First time? Run:"
echo "    make kernel-download KERNEL=6.6  # Download kernel source"
echo ""
echo "  Help:"
echo "    make help                        # Show all available targets"
echo "    make list-boards                 # List supported boards"
echo "======================================"

if is_cnb_ide; then
    echo ""
    log_info "CNB Cloud IDE detected — KVM disabled, using software emulation"

    # Warn about ephemeral storage
    if ! mountpoint -q /workspace 2>/dev/null; then
        log_warn "Workspace may be on ephemeral storage."
        log_warn "Build artifacts in output/ and sources in src/ may be lost on restart."
    fi
fi

echo ""
