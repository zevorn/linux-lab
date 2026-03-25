#!/bin/bash
set -euo pipefail
# Rootfs management: prepare prebuilt, build via Buildroot, inject modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/cnb-detect.sh"

ACTION="${1:?Usage: rootfs.sh <prepare|build|rebuild|menuconfig|modules|clean>}"

ROOTFS_OUT="$BOARD_OUTPUT/rootfs"
ROOTFS_WORK="$ROOTFS_OUT/work"

rootfs_prepare() {
    ensure_dir "$ROOTFS_OUT"

    # Priority: ROOTFS_IMAGE > ROOTFS_SRC directory > ROOTFS_PREBUILT > minimal fallback

    # 1. Direct image file
    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        log_info "Using custom rootfs image: $ROOTFS_IMAGE"
        cp "$ROOTFS_IMAGE" "$ROOTFS_OUT/rootfs.cpio.gz"
        log_ok "Rootfs ready"
        return 0
    fi

    # 2. ROOTFS_SRC directory mode (expects rootfs.cpio.gz inside)
    if [ -n "$ROOTFS_SRC" ] && [ -d "$ROOTFS_SRC" ]; then
        local src_image="$ROOTFS_SRC/rootfs.cpio.gz"
        if [ -f "$src_image" ]; then
            log_info "Using rootfs from ROOTFS_SRC: $src_image"
            cp "$src_image" "$ROOTFS_OUT/rootfs.cpio.gz"
            log_ok "Rootfs ready"
            return 0
        else
            log_warn "ROOTFS_SRC=$ROOTFS_SRC exists but contains no rootfs.cpio.gz"
        fi
    fi

    # 3. Prebuilt rootfs from repo
    if [ -f "$ROOTFS_PREBUILT" ]; then
        log_info "Using prebuilt rootfs: $ROOTFS_PREBUILT"
        cp "$ROOTFS_PREBUILT" "$ROOTFS_OUT/rootfs.cpio.gz"

        if [ -d "$TOP_DIR/rootfs/overlay" ]; then
            log_info "Applying overlay files..."
            rootfs_apply_overlay
        fi
    else
        # 4. Minimal fallback
        log_info "No prebuilt rootfs found, building minimal rootfs..."
        rootfs_build_minimal
    fi

    log_ok "Rootfs ready at $ROOTFS_OUT/rootfs.cpio.gz"
}

rootfs_build_minimal() {
    # Build a minimal rootfs from scratch using busybox
    check_cmd fakeroot
    ensure_dir "$ROOTFS_WORK"

    log_info "Creating minimal rootfs structure..."
    local rootfs_dir="$ROOTFS_WORK/rootfs"
    rm -rf "$rootfs_dir"
    mkdir -p "$rootfs_dir"/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/{bin,sbin},var,lib}

    # Check for busybox in PATH (cross-compiled or static)
    local busybox_bin
    busybox_bin=$(which "${CROSS_COMPILE}busybox" 2>/dev/null || \
                  which busybox-"$BOARD_ARCH" 2>/dev/null || \
                  echo "")

    if [ -n "$busybox_bin" ]; then
        cp "$busybox_bin" "$rootfs_dir/bin/busybox"
        chmod +x "$rootfs_dir/bin/busybox"
        # Install busybox symlinks (no chroot — may lack root/CAP_SYS_CHROOT in container)
        (cd "$rootfs_dir" && for cmd in sh ls cat echo mount umount mkdir rm cp mv \
            ps top kill sleep date df du head tail grep sed awk vi; do
            ln -sf busybox "bin/$cmd"
        done
        for cmd in init halt reboot; do
            ln -sf ../bin/busybox "sbin/$cmd"
        done)
    else
        log_warn "No busybox found for $BOARD_ARCH. Rootfs will be minimal."
        # Create a minimal /init
        cat > "$rootfs_dir/init" << 'INIT_EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
echo "Linux Lab minimal init — no busybox available"
exec /bin/sh 2>/dev/null || exec sh
INIT_EOF
        chmod +x "$rootfs_dir/init"
    fi

    # Copy overlay
    if [ -d "$TOP_DIR/rootfs/overlay" ]; then
        cp -a "$TOP_DIR/rootfs/overlay/." "$rootfs_dir/"
    fi

    # Create cpio archive
    log_info "Creating cpio archive..."
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")
    log_ok "Minimal rootfs created: $ROOTFS_OUT/rootfs.cpio.gz"
}

rootfs_apply_overlay() {
    # Unpack existing cpio, overlay files, repack
    local rootfs_dir="$ROOTFS_WORK/rootfs-overlay"
    ensure_dir "$rootfs_dir"

    # Unpack
    (cd "$rootfs_dir" && zcat "$ROOTFS_OUT/rootfs.cpio.gz" | fakeroot cpio -idm 2>/dev/null)

    # Overlay
    cp -a "$TOP_DIR/rootfs/overlay/." "$rootfs_dir/"

    # Repack
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")

    rm -rf "$rootfs_dir"
}

rootfs_build() {
    check_file "$BUILDROOT_SRC/Makefile" "Buildroot source not found. Run 'git submodule update --init src/buildroot'"
    check_disk_space 5120 "$OUTPUT_DIR"
    setup_logging "$BOARD" "rootfs-build"

    local br_out="$ROOTFS_OUT/buildroot"
    ensure_dir "$br_out"

    log_info "Building rootfs via Buildroot ($ROOTFS_BUILDROOT_DEFCONFIG)..."
    run_logged make -C "$BUILDROOT_SRC" O="$br_out" \
        "$ROOTFS_BUILDROOT_DEFCONFIG" || {
        show_log_tail
        log_fatal "Buildroot defconfig failed"
    }

    run_logged make -C "$BUILDROOT_SRC" O="$br_out" -j"$JOBS" || {
        show_log_tail
        log_fatal "Buildroot build failed"
    }

    # Copy output image
    local br_image="$br_out/images/rootfs.cpio.gz"
    if [ -f "$br_image" ]; then
        cp "$br_image" "$ROOTFS_OUT/rootfs.cpio.gz"
        log_ok "Buildroot rootfs ready: $ROOTFS_OUT/rootfs.cpio.gz"
    else
        log_fatal "Buildroot output not found at $br_image"
    fi
}

rootfs_rebuild() {
    check_file "$ROOTFS_OUT/buildroot/.config" "Run 'make rootfs-build' first"
    setup_logging "$BOARD" "rootfs-rebuild"

    log_info "Rebuilding rootfs (incremental)..."
    run_logged make -C "$BUILDROOT_SRC" O="$ROOTFS_OUT/buildroot" -j"$JOBS" || {
        show_log_tail
        log_fatal "Buildroot rebuild failed"
    }
    cp "$ROOTFS_OUT/buildroot/images/rootfs.cpio.gz" "$ROOTFS_OUT/rootfs.cpio.gz"
    log_ok "Rootfs rebuild complete"
}

rootfs_menuconfig() {
    check_file "$BUILDROOT_SRC/Makefile" "Buildroot source not found"
    local br_out="$ROOTFS_OUT/buildroot"
    ensure_dir "$br_out"

    if [ ! -f "$br_out/.config" ]; then
        make -C "$BUILDROOT_SRC" O="$br_out" "$ROOTFS_BUILDROOT_DEFCONFIG"
    fi

    make -C "$BUILDROOT_SRC" O="$br_out" menuconfig
}

rootfs_modules() {
    check_file "$KERNEL_OUT/.config" "Kernel not built. Run 'make kernel-build' first"
    check_cmd fakeroot
    ensure_dir "$ROOTFS_WORK"

    local rootfs_dir="$ROOTFS_WORK/rootfs-modules"
    local modules_dir="$ROOTFS_WORK/modules-tmp"
    ensure_dir "$rootfs_dir" "$modules_dir"

    log_info "Installing kernel modules..."
    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        INSTALL_MOD_PATH="$modules_dir" modules_install

    # Unpack existing rootfs
    (cd "$rootfs_dir" && zcat "$ROOTFS_OUT/rootfs.cpio.gz" | fakeroot cpio -idm 2>/dev/null)

    # Copy modules
    cp -a "$modules_dir/lib" "$rootfs_dir/"

    # Repack
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")

    rm -rf "$rootfs_dir" "$modules_dir"
    log_ok "Kernel modules injected into rootfs"
}

rootfs_clean() {
    if [ -d "$ROOTFS_OUT" ]; then
        log_info "Cleaning rootfs: $ROOTFS_OUT"
        rm -rf "$ROOTFS_OUT"
        log_ok "Cleaned"
    else
        log_info "Nothing to clean"
    fi
}

case "$ACTION" in
    prepare)     rootfs_prepare ;;
    build)       rootfs_build ;;
    rebuild)     rootfs_rebuild ;;
    menuconfig)  rootfs_menuconfig ;;
    modules)     rootfs_modules ;;
    clean)       rootfs_clean ;;
    *)           log_fatal "Unknown action: $ACTION" ;;
esac
