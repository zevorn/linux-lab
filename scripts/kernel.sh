#!/bin/bash
# Kernel source management: download, patch, config, build
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:?Usage: kernel.sh <download|patch|config|menuconfig|build|rebuild|clean|saveconfig|export-patches>}"

kernel_download() {
    if [ -d "$KERNEL_SRC" ] && [ -f "$KERNEL_SRC/Makefile" ]; then
        log_info "Kernel source already exists at $KERNEL_SRC"
        return 0
    fi

    check_disk_space 2048 "$SRC_DIR"

    if [ "$KERNEL_GIT" = "1" ]; then
        log_info "Cloning kernel $KERNEL via git..."
        check_cmd git
        git clone --branch "v${KERNEL}" --depth=1 \
            "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git" \
            "$KERNEL_SRC"
    else
        local tarball="${SRC_DIR}/linux-${KERNEL}.tar.xz"
        download_file "$KERNEL_URL" "$KERNEL_URL_ALT" "$tarball" "$KERNEL_SHA256"

        log_info "Extracting kernel source..."
        ensure_dir "$SRC_DIR"
        tar xf "$tarball" -C "$SRC_DIR"

        # Handle directory naming (linux-6.6 vs linux-6.6.x)
        local extracted
        extracted=$(find "$SRC_DIR" -maxdepth 1 -type d -name "linux-${KERNEL}*" | head -1)
        if [ "$extracted" != "$KERNEL_SRC" ] && [ -n "$extracted" ]; then
            mv "$extracted" "$KERNEL_SRC"
        fi

        rm -f "$tarball"
    fi

    log_ok "Kernel source ready at $KERNEL_SRC"
}

kernel_patch() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"

    local applied=0

    # Apply patches in order: common -> version -> board
    for patch_dir in \
        "$PATCHES_DIR/linux/common" \
        "$PATCHES_DIR/linux/$KERNEL" \
        "$PATCHES_DIR/linux/$BOARD"; do

        [ -d "$patch_dir" ] || continue

        for patch in "$patch_dir"/*.patch; do
            [ -f "$patch" ] || continue
            log_info "Applying patch: $(basename "$patch")"
            (cd "$KERNEL_SRC" && patch -p1 -N < "$patch") || \
                log_warn "Patch may already be applied: $(basename "$patch")"
            applied=$((applied + 1))
        done
    done

    if [ "$applied" -eq 0 ]; then
        log_info "No patches to apply"
    else
        log_ok "Applied $applied patch(es)"
    fi
}

kernel_config() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"
    ensure_dir "$KERNEL_OUT"

    setup_logging "$BOARD" "kernel-config"

    log_info "Generating kernel config: $KERNEL_DEFCONFIG"
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        "$KERNEL_DEFCONFIG"

    if [ -n "$KERNEL_CONFIG_EXTRA" ] && [ -f "$KERNEL_CONFIG_EXTRA" ]; then
        log_info "Merging extra config: $KERNEL_CONFIG_EXTRA"
        "$KERNEL_SRC/scripts/kconfig/merge_config.sh" \
            -m -O "$KERNEL_OUT" \
            "$KERNEL_OUT/.config" "$KERNEL_CONFIG_EXTRA"
    fi

    log_ok "Kernel config ready at $KERNEL_OUT/.config"
}

kernel_menuconfig() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"
    ensure_dir "$KERNEL_OUT"

    # Generate default config first if none exists
    if [ ! -f "$KERNEL_OUT/.config" ]; then
        kernel_config
    fi

    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        menuconfig
}

kernel_build() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"

    # Auto-config if no .config
    if [ ! -f "$KERNEL_OUT/.config" ]; then
        kernel_config
    fi

    check_disk_space 3072 "$OUTPUT_DIR"
    setup_logging "$BOARD" "kernel-build"

    log_info "Building kernel $KERNEL for $BOARD ($KERNEL_IMAGE)..."
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" "$KERNEL_IMAGE" dtbs modules || {
        show_log_tail
        log_fatal "Kernel build failed"
    }

    log_ok "Kernel built: $KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
}

kernel_rebuild() {
    check_file "$KERNEL_OUT/.config" "Run 'make kernel-build' first"
    setup_logging "$BOARD" "kernel-rebuild"

    log_info "Rebuilding kernel (incremental)..."
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" "$KERNEL_IMAGE" dtbs modules || {
        show_log_tail
        log_fatal "Kernel rebuild failed"
    }

    log_ok "Kernel rebuild complete"
}

kernel_clean() {
    if [ -d "$KERNEL_OUT" ]; then
        log_info "Cleaning kernel build: $KERNEL_OUT"
        rm -rf "$KERNEL_OUT"
        log_ok "Cleaned"
    else
        log_info "Nothing to clean"
    fi
}

kernel_saveconfig() {
    check_file "$KERNEL_OUT/.config" "Run 'make kernel-config' first"

    local fragment="$CONFIGS_DIR/${BOARD_ARCH}_$(echo "$BOARD_NAME" | tr '/' '_')_${KERNEL}.config"
    ensure_dir "$CONFIGS_DIR"

    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        savedefconfig

    cp "$KERNEL_OUT/defconfig" "$fragment"
    log_ok "Config fragment saved: $fragment"
}

kernel_export_patches() {
    check_file "$KERNEL_SRC/Makefile" "No kernel source found"
    check_cmd git

    local patch_dir="$PATCHES_DIR/linux/$KERNEL"
    ensure_dir "$patch_dir"

    if [ -d "$KERNEL_SRC/.git" ]; then
        (cd "$KERNEL_SRC" && git format-patch -o "$patch_dir" HEAD~1)
        log_ok "Patches exported to $patch_dir"
    else
        log_warn "Kernel source is not a git repo. Use KERNEL_GIT=1 for git-based workflow."
    fi
}

case "$ACTION" in
    download)        kernel_download ;;
    patch)           kernel_patch ;;
    config)          kernel_config ;;
    menuconfig)      kernel_menuconfig ;;
    build)           kernel_build ;;
    rebuild)         kernel_rebuild ;;
    clean)           kernel_clean ;;
    saveconfig)      kernel_saveconfig ;;
    export-patches)  kernel_export_patches ;;
    *)               log_fatal "Unknown action: $ACTION" ;;
esac
