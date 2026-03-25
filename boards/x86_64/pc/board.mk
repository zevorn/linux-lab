# x86_64 PC board configuration

BOARD_NAME     ?= pc
BOARD_ARCH     ?= x86_64
BOARD_DESC     ?= x86_64 PC (TCG, no KVM — expect slower boot)

CROSS_COMPILE  ?=
TOOLCHAIN_TYPE ?= dynamic

QEMU_SYSTEM    ?= qemu-system-x86_64
QEMU_MACHINE   ?= pc
QEMU_CPU       ?= qemu64
QEMU_MEM       ?= 512M
QEMU_NET       ?= -netdev user,id=net0 -device virtio-net-pci,netdev=net0
QEMU_DISPLAY   ?= -nographic
QEMU_EXTRA     ?=

KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 6.1 6.6
KERNEL_IMAGE      ?= bzImage
KERNEL_DTB        ?=

GDB_PORT       ?= 1234
GDB_ARCH       ?= i386:x86-64
