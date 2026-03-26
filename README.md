# Linux Lab

A Docker + QEMU based Linux kernel development platform running on [CNB Cloud IDE](https://cnb.cool).

One-click boot for ARM, RISC-V, and x86_64 boards — designed for teaching, learning, and kernel development.

## Quick Start

### On CNB Cloud IDE

1. Fork this repository on CNB
2. Click **Cloud IDE** to open the development environment
3. Run in terminal:

```bash
make boot
```

This automatically downloads the kernel, prepares rootfs, and boots QEMU. You'll see a login prompt within minutes.

### Locally with Docker

```bash
docker build -t linux-lab .
docker run -it --rm -v $(pwd):/workspace linux-lab
make boot
```

### Locally without Docker

Requirements: QEMU, ARM cross-compiler (e.g., `arm-linux-gnueabihf-gcc`), standard build tools.

```bash
git clone --recurse-submodules https://github.com/zevorn/linux-lab.git
cd linux-lab
make boot BOARD=arm/vexpress-a9
```

## Supported Boards

| Board | Architecture | QEMU Machine | Kernel Versions |
|-------|-------------|--------------|-----------------|
| `arm/vexpress-a9` | ARM Cortex-A9 | vexpress-a9 | 5.15, 6.1, 6.6 |
| `riscv/virt` | RISC-V 64-bit | virt | 6.1, 6.6 |
| `x86_64/pc` | x86_64 | pc | 6.1, 6.6 |

## Key Commands

```bash
# One-click boot (fully autonomous)
make boot                              # Default: ARM vexpress-a9 + kernel 6.6
make boot BOARD=riscv/virt             # RISC-V board
make boot BOARD=x86_64/pc             # x86_64 board

# TUI interactive mode
make tui

# Kernel management
make kernel-download KERNEL=6.6       # Download kernel source
make kernel-menuconfig                 # Configure kernel
make kernel-build                      # Build kernel

# Rootfs
make rootfs-prepare                    # Prepare prebuilt rootfs
make rootfs-build                      # Build via Buildroot

# QEMU
make qemu-build                        # Build QEMU from source
make qemu-debug                        # Boot with GDB server (-s -S)
make debug                             # Connect GDB to QEMU

# Info
make help                              # Show all targets
make info                              # Show current configuration
make list-boards                       # List available boards
```

## Project Structure

```
linux-lab/
├── Makefile                # Main entry point
├── Dockerfile              # CNB Cloud IDE image
├── boards/                 # Board configurations (declarative .mk files)
│   ├── arm/vexpress-a9/
│   ├── riscv/virt/
│   └── x86_64/pc/
├── scripts/                # Core engine (shell scripts)
│   ├── kernel.sh           # Kernel download/build
│   ├── rootfs.sh           # Rootfs management
│   ├── qemu.sh             # QEMU boot/build
│   └── tui/                # TUI interface
├── rootfs/
│   ├── prebuilt/           # Prebuilt rootfs images (per arch)
│   └── overlay/            # Rootfs overlay files
├── src/                    # Source code
│   ├── qemu/               # QEMU (git submodule)
│   └── buildroot/          # Buildroot (git submodule)
└── docs/                   # Documentation (zh/en)
```

## Configuration

Override defaults via CLI, environment variables, or `.linux-lab.conf`:

```bash
# CLI override
make boot BOARD=riscv/virt KERNEL=6.1

# Persistent config
echo "BOARD := riscv/virt" > .linux-lab.conf
echo "KERNEL := 6.1" >> .linux-lab.conf
make boot

# Custom kernel/rootfs source
make kernel-build KERNEL_SRC=/path/to/my-linux
make boot ROOTFS_IMAGE=/path/to/my-rootfs.cpio.gz
```

## Adding a New Board

### Via TUI

```bash
make tui  # Select "Add new board"
```

### Manually

1. Create `boards/<arch>/<board>/board.mk`, `kernel-<ver>.mk`, `rootfs.mk`
2. Verify: `make info BOARD=<arch>/<board>`

See [Board Guide (EN)](docs/en/board-guide.md) | [开发板指南 (中文)](docs/zh/board-guide.md)

## GDB Debugging

Terminal 1:
```bash
make qemu-debug                  # Boot with -s -S
```

Terminal 2:
```bash
make debug                       # Launch gdb-multiarch, connect to :1234
```

## Documentation

- [Getting Started (EN)](docs/en/getting-started.md) | [快速上手 (中文)](docs/zh/getting-started.md)
- [Board Guide (EN)](docs/en/board-guide.md) | [开发板指南 (中文)](docs/zh/board-guide.md)

## License

This project is licensed under the GPL-2.0 License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by [TinyLab's Linux Lab](https://gitee.com/tinylab/linux-lab). Fully re-implemented for CNB Cloud IDE.
