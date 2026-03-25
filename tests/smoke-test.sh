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
echo "--- Kernel version validation ---"
check_fail() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  FAIL: $desc (expected failure but got success)"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $desc (correctly rejected)"
        PASS=$((PASS + 1))
    fi
}
check_fail "reject unsupported kernel KERNEL=9.9" make info BOARD=arm/vexpress-a9 KERNEL=9.9
check_fail "reject nonexistent board" make info BOARD=nonexistent/board

echo ""
echo "--- Script syntax (bash -n) ---"
for script in scripts/*.sh scripts/tui/*.sh; do
    [ -f "$script" ] || continue
    check "bash -n $script" bash -n "$script"
done

echo ""
echo "--- Script syntax (shellcheck) ---"
if command -v shellcheck >/dev/null 2>&1; then
    check "shellcheck (all scripts, -x -S warning)" \
        shellcheck -x -S warning scripts/*.sh scripts/tui/*.sh tests/*.sh
else
    echo "  FAIL: shellcheck not installed — AC-9 requires it"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "--- Submodule state ---"
check ".gitmodules exists" test -f .gitmodules
check "QEMU submodule configured" git config --file .gitmodules --get submodule.src/qemu.url
check "Buildroot submodule configured" git config --file .gitmodules --get submodule.src/buildroot.url

echo ""
echo "--- Essential files exist ---"
for f in Makefile Dockerfile .cnb.yml .ide.yaml rootfs/busybox.config src/.gitkeep; do
    check "file exists: $f" test -f "$f"
done

echo ""
echo "--- Script permissions ---"
for script in scripts/*.sh scripts/tui/*.sh tests/*.sh; do
    [ -f "$script" ] || continue
    check "executable: $script" test -x "$script"
done

echo ""
echo "--- Boot test (requires QEMU + toolchain) ---"
if command -v qemu-system-arm >/dev/null 2>&1 && command -v arm-linux-gnueabihf-gcc >/dev/null 2>&1; then
    check "make boot-test BOARD=arm/vexpress-a9" \
        make -C "$TOP_DIR" boot-test BOARD=arm/vexpress-a9 KERNEL=6.6
else
    echo "  SKIP: boot-test requires QEMU + ARM cross-compiler (run inside Docker image)"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
