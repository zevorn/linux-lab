# Linux Lab Getting Started Guide

## Prerequisites

- A CNB (Cloud Native Build) account
- Fork this repository to your CNB account
- A modern browser (Chrome / Firefox recommended)

For local usage, you also need:

- Docker installed and running
- At least 10GB free disk space
- Git

## Open Cloud IDE

1. Fork the `linux-lab` repository on CNB
2. Click the **Cloud IDE** button on the repository page
3. Wait for the environment to initialize (about 1-2 minutes for the first time)
4. The terminal automatically displays a welcome message and environment status

## First Boot

Open a terminal and run the one-click boot command:

```bash
make boot
```

This command automatically performs the following steps:

1. Check kernel source — auto-download if missing
2. Check kernel image — auto-build if missing
3. Check rootfs — auto-prepare if missing (uses repo prebuilt images)
4. Check QEMU — use system/Docker-provided version, or auto-build from source
5. Launch QEMU virtual machine

By default, it boots the ARM vexpress-a9 board with Linux 6.6 kernel.

After boot, you will see `Welcome to Linux Lab minimal rootfs` and a `~ #` shell prompt. You are dropped directly into a root shell without login.

To exit QEMU: press `Ctrl-A` then `X`.

## TUI Interactive Interface

Linux Lab provides a dialog-based TUI interactive interface:

```bash
make tui
```

The TUI main menu includes:

| Option | Description |
|--------|-------------|
| 1. Select board and boot | Choose a board and boot it |
| 2. Kernel management | Kernel operations (download, build, configure) |
| 3. Rootfs management | Root filesystem management |
| 4. QEMU management | QEMU management |
| 5. Add new board | Add a new board (wizard) |
| 6. System info | System information |

Use arrow keys to navigate, Enter to select, ESC to go back.

## Command Reference

### One-Click Operations

| Command | Description |
|---------|-------------|
| `make boot` | Full flow: build kernel + prepare rootfs + boot QEMU |
| `make tui` | Open TUI interactive interface |
| `make boot BOARD=riscv/virt` | Boot RISC-V board |
| `make boot BOARD=x86_64/pc` | Boot x86_64 board |

### Kernel Management

| Command | Description |
|---------|-------------|
| `make kernel-download` | Download kernel source to src/ |
| `make kernel-download KERNEL=5.15` | Download a specific kernel version |
| `make kernel-config` | Generate .config |
| `make kernel-menuconfig` | Interactive kernel configuration |
| `make kernel-build` | Build kernel |
| `make kernel-rebuild` | Incremental kernel rebuild |
| `make kernel-clean` | Clean kernel build artifacts |
| `make kernel-saveconfig` | Export config diff as fragment |

### Root Filesystem

| Command | Description |
|---------|-------------|
| `make rootfs-prepare` | Prepare prebuilt rootfs + overlay |
| `make rootfs-build` | Full Buildroot build |
| `make rootfs-modules` | Inject kernel modules into rootfs |
| `make rootfs-menuconfig` | Buildroot interactive configuration |

### QEMU

| Command | Description |
|---------|-------------|
| `make qemu-boot` | Boot QEMU only (skip kernel build) |
| `make qemu-debug` | Boot QEMU with GDB debug mode |
| `make qemu-build` | Build QEMU from source (requires submodule init) |
| `make check-submodules` | Initialize QEMU and Buildroot git submodules |

### Environment

| Command | Description |
|---------|-------------|
| `make info` | Show current configuration |
| `make list-boards` | List available boards |
| `make list-kernels` | List supported kernel versions for current board |
| `make help` | Show all make targets |
| `make clean` | Clean current board build artifacts |
| `make distclean` | Clean everything including downloaded sources |
| `make disk-usage` | Show disk usage breakdown |

## Kernel Download and Build

### Download Kernel Source

```bash
# Download default version (defined by KERNEL_DEFAULT in board.mk)
make kernel-download

# Download a specific version
make kernel-download KERNEL=6.1

# Use git clone (when full history is needed)
make kernel-download KERNEL=6.6 KERNEL_GIT=1
```

Kernel source is downloaded to `src/linux-<version>/`. Chinese mirror is used by default for faster downloads.

### Build Kernel

```bash
# Build (automatically uses -j$(nproc) for parallel compilation)
make kernel-build

# Modify config before building
make kernel-menuconfig
make kernel-build

# Build for a different board
make kernel-build BOARD=riscv/virt KERNEL=6.6
```

Build artifacts go to `output/<board>/linux-<version>/` (out-of-tree build, so the same source tree can be shared across boards).

### Use Custom Kernel Source

```bash
make kernel-build BOARD=arm/vexpress-a9 KERNEL_SRC=/path/to/my-linux
```

## GDB Debugging

GDB debugging requires two terminals:

**Terminal 1** — Boot QEMU in debug mode:

```bash
make qemu-debug
```

QEMU starts with `-s -S` flags, waiting for GDB connection (default port 1234).

**Terminal 2** — Launch GDB and connect:

```bash
make debug
```

This command automatically:
1. Launches `gdb-multiarch`
2. Loads the current kernel's `vmlinux` symbol file
3. Connects to the QEMU GDB server (`target remote :1234`)

### Common GDB Commands

```
(gdb) break start_kernel        # Set breakpoint at start_kernel
(gdb) continue                   # Continue execution
(gdb) bt                         # View call stack
(gdb) list                       # View source code
(gdb) print task_struct          # Print variable
(gdb) info registers             # View registers
```

## Switching Boards

```bash
# Use command-line arguments
make boot BOARD=riscv/virt
make boot BOARD=x86_64/pc

# Persistent configuration (write to .linux-lab.conf)
echo "BOARD := riscv/virt" > .linux-lab.conf
make boot
```

Configuration priority: CLI args > environment variables > `.linux-lab.conf` > board defaults.

## Custom Rootfs

```bash
# Use a custom rootfs directory (should contain rootfs.cpio.gz)
make boot BOARD=arm/vexpress-a9 ROOTFS_SRC=/path/to/my-rootfs/

# Specify a rootfs image file directly
make boot BOARD=arm/vexpress-a9 ROOTFS_IMAGE=/path/to/my-rootfs.cpio.gz
```

## Troubleshooting

### QEMU Boot Is Slow

CNB Cloud IDE does not have KVM support. QEMU uses pure software emulation (TCG mode). x86_64-on-x86_64 is approximately 10-50x slower, and kernel boot is expected to take 2-5 minutes. This is sufficient for teaching and debugging scenarios.

### Disk Space Issues

```bash
make disk-usage        # View disk usage breakdown
make clean             # Clean current board build artifacts
make distclean         # Clean everything
```

### Download Failures

Kernel download uses Chinese mirror (Tsinghua) by default and automatically falls back to cdn.kernel.org on failure. You can also configure the mirror manually:

```bash
echo 'KERNEL_MIRROR := https://mirrors.aliyun.com/kernel' >> .linux-lab.conf
```
