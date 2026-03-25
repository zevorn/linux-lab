# ARM Versatile Express Cortex-A9 board configuration

# Board metadata
BOARD_NAME     ?= vexpress-a9
BOARD_ARCH     ?= arm
BOARD_DESC     ?= ARM Versatile Express Cortex-A9

# Toolchain
CROSS_COMPILE  ?= arm-linux-gnueabihf-
TOOLCHAIN_TYPE ?= dynamic

# QEMU
QEMU_SYSTEM    ?= qemu-system-arm
QEMU_MACHINE   ?= vexpress-a9
QEMU_CPU       ?=
QEMU_MEM       ?= 512M
QEMU_NET       ?= -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-device,netdev=net0
QEMU_DISPLAY   ?= -nographic
QEMU_EXTRA     ?=

# Kernel
KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 5.15 6.1 6.6
KERNEL_IMAGE      ?= zImage
KERNEL_DTB        ?= vexpress-v2p-ca9.dtb

# Debug
GDB_PORT       ?= 1234
GDB_ARCH       ?= arm
