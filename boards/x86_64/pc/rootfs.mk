ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/x86_64/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_x86_64_defconfig
ROOTFS_APPEND              ?= console=ttyS0 rdinit=/sbin/init
