ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/riscv/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_riscv64_virt_defconfig
ROOTFS_APPEND              ?= console=ttyS0 rdinit=/sbin/init
