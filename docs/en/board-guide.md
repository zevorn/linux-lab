# Board Configuration Guide

## Configuration File Structure

Each board is defined by three configuration files:

```
boards/<arch>/<board>/
├── board.mk            # Board-level common config
├── kernel-<ver>.mk     # Kernel version specific config
└── rootfs.mk           # Root filesystem config
```

## board.mk Format

```makefile
BOARD_NAME     ?= <board-name>
BOARD_ARCH     ?= <arm|riscv|x86_64>
BOARD_DESC     ?= <description>
CROSS_COMPILE  ?= <cross-compiler-prefix>
QEMU_SYSTEM    ?= <qemu-system-xxx>
QEMU_MACHINE   ?= <machine-type>
QEMU_MEM       ?= 512M
KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 6.1 6.6
KERNEL_IMAGE      ?= <zImage|Image|bzImage>
GDB_PORT       ?= 1234
```

## Adding a Board Manually

1. Create directory: `mkdir -p boards/<arch>/<board>`
2. Write `board.mk`, `kernel-<ver>.mk`, `rootfs.mk`
3. Verify: `make info BOARD=<arch>/<board>`

## Adding a Board via TUI

```bash
make tui  # Select "5. Add new board"
```

## Patch Application Order

```
patches/linux/common/     → All kernel versions
patches/linux/<version>/  → Version specific
patches/linux/<board>/    → Board specific
```

## QEMU Parameters Reference

| Arch | QEMU System | Machine | Kernel Image | Serial |
|------|-------------|---------|--------------|--------|
| ARM | qemu-system-arm | vexpress-a9 | zImage | ttyAMA0 |
| RISC-V | qemu-system-riscv64 | virt | Image | ttyS0 |
| x86_64 | qemu-system-x86_64 | pc | bzImage | ttyS0 |
