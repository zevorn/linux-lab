# Rootfs configuration for ARM vexpress-a9

ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/arm/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_arm_vexpress_defconfig
ROOTFS_APPEND              ?= console=ttyAMA0 rdinit=/sbin/init
