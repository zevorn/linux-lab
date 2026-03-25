#!/bin/bash
# Smoke test: verify Makefile targets and basic functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOP_DIR="$(dirname "$SCRIPT_DIR")"
cd "$TOP_DIR"

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Linux Lab Smoke Tests ==="
echo ""

echo "--- Makefile targets (dry-run) ---"
check "make help"         make help
check "make info"         make info
check "make list-boards"  make list-boards
check "make list-kernels" make list-kernels

echo ""
echo "--- Board configs ---"
for board in arm/vexpress-a9 riscv/virt x86_64/pc; do
    check "make info BOARD=$board" make info BOARD="$board"
done

echo ""
echo "--- Script syntax (shellcheck) ---"
if command -v shellcheck >/dev/null 2>&1; then
    for script in scripts/*.sh scripts/tui/*.sh; do
        [ -f "$script" ] || continue
        check "shellcheck $script" shellcheck "$script"
    done
else
    echo "  SKIP: shellcheck not installed"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
