#!/bin/bash
set -euo pipefail
# QEMU management: build, boot, debug, boot-test
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/cnb-detect.sh"

ACTION="${1:?Usage: qemu.sh <build|rebuild|boot|boot-auto|debug|boot-test|export-patches>}"

qemu_build() {
    check_file "$QEMU_SRC/configure" "QEMU source not found. Run 'git submodule update --init src/qemu'"
    check_disk_space 3072 "$OUTPUT_DIR"
    setup_logging "qemu" "qemu-build"

    local qemu_build_dir="$OUTPUT_DIR/qemu-build"
    local qemu_install_dir="$OUTPUT_DIR/qemu"
    ensure_dir "$qemu_build_dir"

    log_info "Configuring and building QEMU (this may take a while)..."
    (
        cd "$qemu_build_dir" || exit 1
        run_logged "$QEMU_SRC/configure" \
            --prefix="$qemu_install_dir" \
            --target-list=arm-softmmu,riscv64-softmmu,x86_64-softmmu \
            --disable-werror || {
            show_log_tail
            log_fatal "QEMU configure failed"
        }

        run_logged make -j"$JOBS" || {
            show_log_tail
            log_fatal "QEMU build failed"
        }

        run_logged make install
    )
    log_ok "QEMU installed to $qemu_install_dir"
}

qemu_rebuild() {
    local qemu_build_dir="$OUTPUT_DIR/qemu-build"
    check_file "$qemu_build_dir/Makefile" "Run 'make qemu-build' first"
    setup_logging "qemu" "qemu-rebuild"

    log_info "Rebuilding QEMU (incremental)..."
    (
        cd "$qemu_build_dir" || exit 1
        run_logged make -j"$JOBS" || {
            show_log_tail
            log_fatal "QEMU rebuild failed"
        }
        run_logged make install
    )
    log_ok "QEMU rebuild complete"
}

# Assemble QEMU command line from board config
qemu_assemble_cmd() {
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local dtb_file=""
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"

    # Resolve DTB path
    if [ -n "$KERNEL_DTB" ]; then
        dtb_file="$KERNEL_OUT/arch/$BOARD_ARCH/boot/dts/$KERNEL_DTB"
    fi

    # Resolve rootfs
    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        rootfs_file="$ROOTFS_IMAGE"
    fi

    # Build command
    QEMU_CMD=("$QEMU_BIN")
    QEMU_CMD+=(-machine "$QEMU_MACHINE")
    [ -n "$QEMU_CPU" ] && QEMU_CMD+=(-cpu "$QEMU_CPU")
    QEMU_CMD+=(-m "$QEMU_MEM")
    QEMU_CMD+=(-kernel "$kernel_image")
    [ -n "$dtb_file" ] && QEMU_CMD+=(-dtb "$dtb_file")
    QEMU_CMD+=(-initrd "$rootfs_file")
    QEMU_CMD+=(-append "$ROOTFS_APPEND")

    # Add network (split on spaces for proper argument handling)
    local net_args
    read -ra net_args <<< "$QEMU_NET"
    QEMU_CMD+=("${net_args[@]}")

    # Display
    local display_args
    read -ra display_args <<< "$QEMU_DISPLAY"
    QEMU_CMD+=("${display_args[@]}")

    # Extra args
    if [ -n "$QEMU_EXTRA" ]; then
        local extra_args
        read -ra extra_args <<< "$QEMU_EXTRA"
        QEMU_CMD+=("${extra_args[@]}")
    fi
}

qemu_pre_check() {
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"
    local ret=0

    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        rootfs_file="$ROOTFS_IMAGE"
    fi

    check_file "$QEMU_BIN" "QEMU not found. Run 'make qemu-build' or install system QEMU" || ret=1
    check_file "$kernel_image" "Kernel image not found. Run 'make kernel-build BOARD=$BOARD KERNEL=$KERNEL'" || ret=1
    check_file "$rootfs_file" "Rootfs not found. Run 'make rootfs-prepare BOARD=$BOARD'" || ret=1

    if [ -n "$KERNEL_DTB" ]; then
        local dtb_file="$KERNEL_OUT/arch/$BOARD_ARCH/boot/dts/$KERNEL_DTB"
        check_file "$dtb_file" "DTB not found. Check KERNEL_DTB in board config" || ret=1
    fi

    return $ret
}

qemu_boot() {
    qemu_pre_check || log_fatal "Pre-boot check failed. Fix the issues above."
    qemu_assemble_cmd

    log_info "Booting $BOARD with kernel $KERNEL..."
    log_info "QEMU command: ${QEMU_CMD[*]}"
    echo ""
    exec "${QEMU_CMD[@]}"
}

qemu_boot_auto() {
    # Fully autonomous boot: auto-download, build, prepare, then boot
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"

    # Auto-download kernel if missing
    if [ ! -f "$KERNEL_SRC/Makefile" ]; then
        log_info "Kernel source not found, downloading linux-$KERNEL..."
        "$SCRIPT_DIR/kernel.sh" download
    fi

    # Auto-build kernel if missing
    if [ ! -f "$kernel_image" ]; then
        log_info "Kernel image not found, building..."
        "$SCRIPT_DIR/kernel.sh" build
    fi

    # Auto-prepare rootfs if missing
    if [ ! -f "$rootfs_file" ]; then
        log_info "Rootfs not found, preparing..."
        "$SCRIPT_DIR/rootfs.sh" prepare
    fi

    # Auto-provision QEMU if not available
    if [ -z "$QEMU_BIN" ] || [ ! -x "$QEMU_BIN" ]; then
        if ! command -v "$QEMU_SYSTEM" >/dev/null 2>&1; then
            log_info "QEMU not found, building from source..."
            make -C "$TOP_DIR" check-submodules
            "$SCRIPT_DIR/qemu.sh" build
            # Re-resolve QEMU_BIN after build
            QEMU_BIN="$OUTPUT_DIR/qemu/bin/$QEMU_SYSTEM"
            export QEMU_BIN
        fi
    fi

    # Boot
    qemu_boot
}

qemu_debug() {
    qemu_pre_check || log_fatal "Pre-boot check failed."
    qemu_assemble_cmd

    # Append debug flags
    QEMU_CMD+=(-s -S)

    log_info "Starting QEMU in debug mode (waiting for GDB on port $GDB_PORT)..."
    log_info "In another terminal, run: make debug BOARD=$BOARD KERNEL=$KERNEL"
    log_info "QEMU command: ${QEMU_CMD[*]}"
    echo ""
    exec "${QEMU_CMD[@]}"
}

qemu_boot_test() {
    # Smoke test: boot and wait for login prompt
    qemu_pre_check || {
        # Auto-prepare for CI
        "$SCRIPT_DIR/kernel.sh" download
        "$SCRIPT_DIR/kernel.sh" build
        "$SCRIPT_DIR/rootfs.sh" prepare
    }
    qemu_assemble_cmd

    local timeout=120
    log_info "Smoke test: booting $BOARD, waiting for login prompt (${timeout}s timeout)..."

    local test_log
    test_log=$(mktemp /tmp/qemu-boot-test.XXXXXX.log)

    # Run QEMU with timeout, look for "login:" in output
    timeout "$timeout" stdbuf -oL "${QEMU_CMD[@]}" 2>&1 | tee "$test_log" &
    local qemu_pid=$!

    # Wait for login prompt
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if grep -q "login:" "$test_log" 2>/dev/null; then
            kill $qemu_pid 2>/dev/null || true
            wait $qemu_pid 2>/dev/null || true
            log_ok "Boot test PASSED — login prompt appeared in ${elapsed}s"
            rm -f "$test_log"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    kill $qemu_pid 2>/dev/null || true
    wait $qemu_pid 2>/dev/null || true
    log_error "Boot test FAILED — no login prompt after ${timeout}s"
    log_error "Last 20 lines of output:"
    tail -20 "$test_log" >&2
    rm -f "$test_log"
    return 1
}

qemu_export_patches() {
    check_file "$QEMU_SRC/configure" "QEMU source not found"
    check_cmd git

    local patch_dir="$PATCHES_DIR/qemu"
    ensure_dir "$patch_dir"

    if [ -d "$QEMU_SRC/.git" ]; then
        (cd "$QEMU_SRC" && git format-patch -o "$patch_dir" HEAD~1)
        log_ok "QEMU patches exported to $patch_dir"
    else
        log_warn "QEMU source is not a git repo"
    fi
}

case "$ACTION" in
    build)          qemu_build ;;
    rebuild)        qemu_rebuild ;;
    boot)           qemu_boot ;;
    boot-auto)      qemu_boot_auto ;;
    debug)          qemu_debug ;;
    boot-test)      qemu_boot_test ;;
    export-patches) qemu_export_patches ;;
    *)              log_fatal "Unknown action: $ACTION" ;;
esac
