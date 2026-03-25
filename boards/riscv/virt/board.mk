# RISC-V virt board configuration

BOARD_NAME     ?= virt
BOARD_ARCH     ?= riscv
BOARD_DESC     ?= RISC-V 64-bit Virtual Machine

CROSS_COMPILE  ?= riscv64-linux-gnu-
TOOLCHAIN_TYPE ?= dynamic

QEMU_SYSTEM    ?= qemu-system-riscv64
QEMU_MACHINE   ?= virt
QEMU_CPU       ?=
QEMU_MEM       ?= 512M
QEMU_NET       ?= -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-device,netdev=net0
QEMU_DISPLAY   ?= -nographic
QEMU_EXTRA     ?=

KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 6.1 6.6
KERNEL_IMAGE      ?= Image
KERNEL_DTB        ?=

GDB_PORT       ?= 1234
GDB_ARCH       ?= riscv:rv64
