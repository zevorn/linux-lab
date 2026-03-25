#!/bin/bash
# Detect CNB Cloud IDE environment and apply adaptations
# Sourced by other scripts, not executed directly

is_cnb_ide() {
    [ -f /.cnb_ide ] || [ -n "${CNB_WORKSPACE:-}" ]
}

apply_cnb_defaults() {
    if is_cnb_ide; then
        # No KVM in container
        export QEMU_KVM="${QEMU_KVM:-n}"
        # Force cpio rootfs (no privileged for loop mount)
        export ROOTFS_TYPE="${ROOTFS_TYPE:-cpio}"
        # User mode networking (no /dev/net/tun)
        export QEMU_NET_MODE="${QEMU_NET_MODE:-user}"
    fi
}

# Auto-apply when sourced
apply_cnb_defaults
