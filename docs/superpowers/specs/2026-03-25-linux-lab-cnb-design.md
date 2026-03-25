# Linux Lab on CNB — Design Specification

## 1. Overview

A Docker + QEMU based Linux development platform running on CNB (Cloud Native Build) Cloud IDE. Provides one-click boot for different architectures and development boards, targeting teaching/learning and kernel development/debugging scenarios.

### Key Decisions

- **Runtime**: Custom Docker image as CNB Cloud IDE base image (no Docker-in-Docker)
- **Source management**: QEMU/Buildroot as git submodules; kernel downloaded on demand; all under `src/` (.gitignore by default)
- **Configuration**: Declarative `.mk` files, board/kernel/rootfs separated
- **User interaction**: Makefile CLI + dialog-based TUI (including board creation wizard)
- **Initial architectures**: ARM (vexpress-a9) + RISC-V (virt) + x86_64
- **Kernel versions**: Multiple LTS versions (5.15, 6.1, 6.6, 6.12)
- **Rootfs**: Prebuilt cpio (Busybox) + optional Buildroot customization
- **QEMU**: Built from source (supports secondary development), software emulation only
- **Fully re-implemented**: Inspired by Taishan linux-lab, no code dependency

## 2. Architecture

```
┌─────────────────────────────────────────────────┐
│                  User Interface                  │
│          Makefile CLI  /  TUI Selector           │
├─────────────────────────────────────────────────┤
│                  Core Engine                     │
│   Kernel Mgmt  │  Rootfs Mgmt  │  QEMU Boot/Dbg │
├─────────────────────────────────────────────────┤
│                  Configuration                   │
│   Board Config  │  Toolchain Config  │  Kernel Config │
├─────────────────────────────────────────────────┤
│                  Infrastructure                  │
│   Docker Image  │  CNB Pipeline  │  CNB Cloud IDE │
└─────────────────────────────────────────────────┘
```

### Data Flow

```
User selects Board + Kernel version
        ↓
Load board.mk + kernel-<ver>.mk config
        ↓
Resolve: ARCH, CROSS_COMPILE, KERNEL_VERSION, QEMU_ARGS, ROOTFS_TYPE
        ↓
┌───────────────┬──────────────────┬────────────────┐
│ kernel-build  │  rootfs-prepare  │  qemu-boot     │
└───────────────┴──────────────────┴────────────────┘
```

### CNB IDE Container Constraints

| Constraint | Impact | Mitigation |
|------------|--------|------------|
| No KVM | QEMU software emulation only, slower | Sufficient for teaching/debugging |
| No privileged | Cannot mount loop devices | Default to cpio/initramfs format; use fakeroot |
| No /dev/net/tun (possibly) | QEMU networking limited | User mode networking (`-netdev user`) |
| Limited storage | Kernel source + build artifacts consume space | Provide `make clean` / `make distclean` |
| No Docker daemon | Cannot run nested containers | All tools installed directly in base image |

## 3. Project Structure

```
linux-lab/
├── .cnb.yml                        # CNB Pipeline config
├── .ide.yaml                       # CNB Cloud IDE config
├── Dockerfile                      # Multi-stage image build
├── Makefile                        # Main entry point
├── .linux-lab.conf                 # User local config (gitignore)
├── boards/                         # Board configs (declarative)
│   ├── arm/
│   │   └── vexpress-a9/
│   │       ├── board.mk
│   │       ├── kernel-5.15.mk
│   │       ├── kernel-6.6.mk
│   │       └── rootfs.mk
│   ├── riscv/
│   │   └── virt/
│   │       ├── board.mk
│   │       ├── kernel-6.1.mk
│   │       ├── kernel-6.6.mk
│   │       └── rootfs.mk
│   └── x86_64/
│       └── pc/
│           ├── board.mk
│           ├── kernel-6.6.mk
│           └── rootfs.mk
├── configs/                        # Kernel config fragments
│   ├── arm_vexpress-a9_5.15.config
│   └── ...
├── toolchains/                     # Toolchain config & wrappers
│   ├── config.mk
│   └── wrappers/
├── rootfs/                         # Root filesystem
│   ├── prebuilt/                   # Prebuilt rootfs (per arch)
│   │   ├── arm/rootfs.cpio.gz
│   │   ├── riscv/rootfs.cpio.gz
│   │   └── x86_64/rootfs.cpio.gz
│   └── overlay/                    # User overlay files
├── patches/                        # Patches for submodules & kernel
│   ├── qemu/
│   ├── buildroot/
│   └── linux/
│       ├── common/
│       ├── 5.15/
│       ├── 6.6/
│       └── arm/vexpress-a9/
├── src/                            # Source code (gitignore by default)
│   ├── qemu/                       # Submodule — secondary development
│   ├── buildroot/                  # Submodule — customization
│   ├── linux-6.6/                  # Downloaded on demand
│   ├── linux-6.1/                  # Downloaded on demand
│   └── rootfs/                     # Build artifacts
├── scripts/                        # Core engine scripts
│   ├── kernel.sh
│   ├── rootfs.sh
│   ├── qemu.sh
│   ├── toolchain.sh
│   ├── debug.sh
│   ├── cnb-detect.sh
│   ├── welcome.sh
│   └── tui/
│       ├── main_menu.sh
│       ├── board_select.sh
│       ├── board_create.sh
│       ├── kernel_menu.sh
│       ├── rootfs_menu.sh
│       ├── qemu_menu.sh
│       └── utils.sh
├── output/                         # Build artifacts (gitignore)
│   └── <board>/<kernel_version>/
├── docs/
│   ├── zh/
│   │   ├── getting-started.md
│   │   └── board-guide.md
│   └── en/
│       ├── getting-started.md
│       └── board-guide.md
└── .gitignore
```

### .gitignore

```gitignore
src/*
!src/qemu/
!src/buildroot/
output/
.linux-lab.conf
```

## 4. Docker Image Design

Multi-stage build, used as CNB Cloud IDE base image.

### Stage Breakdown

| Stage | Contents | Est. Size |
|-------|----------|-----------|
| base | Ubuntu 24.04 + dev tools (git, make, gcc, gdb, python3, flex, bison, libssl-dev, bc, ncurses, fakeroot, cpio, wget, dialog) | ~500MB |
| qemu | QEMU from source (arm-softmmu, riscv64-softmmu, x86_64-softmmu) | ~200MB |
| toolchains | Prebuilt cross-compilers (ARM: Bootlin/Linaro, RISC-V: Bootlin, x86_64: host gcc) | ~1-1.5GB |
| rootfs | Buildroot source + prebuilt rootfs images | ~300MB |
| **Total** | | **~2-2.5GB** |

### Toolchain Coexistence Strategy

Multiple toolchain versions installed to independent prefixes under `/opt/toolchains/`:

```
/opt/toolchains/
├── arm-gcc10/          # For older kernels (5.15)
├── arm-gcc13/          # For newer kernels (6.x)
├── riscv-gcc13/
└── x86_64 → host gcc
```

Compatibility guarantee (priority order):

1. **glibc backward compatibility** (default) — base image uses Ubuntu 24.04 (glibc 2.39), covers most toolchains
2. **Wrapper script + bundled ld/glibc** — for toolchains with specific glibc requirements
3. **Static-linked toolchain** — fallback for extreme cases

Board config binds toolchain version:

```makefile
TOOLCHAIN_TYPE := dynamic   # dynamic | wrapped | static
```

## 5. Board Configuration System

### File Structure

```
boards/<arch>/<board>/
├── board.mk            # Board-level common config
├── kernel-<ver>.mk     # Kernel version specific config
└── rootfs.mk           # Rootfs config
```

### board.mk Format

```makefile
BOARD_NAME    := vexpress-a9
BOARD_ARCH    := arm
BOARD_DESC    := ARM Versatile Express Cortex-A9
CROSS_COMPILE := arm-linux-gnueabihf-
TOOLCHAIN_TYPE := dynamic
QEMU_SYSTEM   := qemu-system-arm
QEMU_MACHINE  := vexpress-a9
QEMU_MEM      := 512M
QEMU_NET      := -netdev user,id=net0 -device virtio-net-device,netdev=net0
QEMU_DISPLAY  := -nographic
KERNEL_DEFAULT   := 6.6
KERNEL_SUPPORTED := 5.15 6.1 6.6
KERNEL_IMAGE     := zImage
KERNEL_DTB       := vexpress-v2p-ca9.dtb
GDB_PORT      := 1234
GDB_ARCH      := arm
```

### kernel-<ver>.mk Format

```makefile
KERNEL_VERSION    := 6.6
KERNEL_URL        := https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
KERNEL_DEFCONFIG  := vexpress_defconfig
KERNEL_CONFIG_EXTRA := $(CONFIGS_DIR)/arm_vexpress-a9_6.6.config
TOOLCHAIN_VERSION := gcc-13
```

### rootfs.mk Format

```makefile
ROOTFS_TYPE       := cpio
ROOTFS_PREBUILT   := $(PREBUILT_DIR)/arm/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG := arm_vexpress_a9_defconfig
ROOTFS_APPEND     := console=ttyAMA0 rdinit=/sbin/init
```

### Config Loading Order

```makefile
include boards/$(BOARD)/board.mk          # Board common
-include boards/$(BOARD)/kernel-$(KERNEL).mk  # Kernel version overrides
include boards/$(BOARD)/rootfs.mk         # Rootfs config
-include .linux-lab.conf                  # User local (highest priority)
```

## 6. Makefile Framework

### Core Targets

```makefile
# One-click
boot                    # Full flow: build kernel + prepare rootfs + boot QEMU
tui                     # TUI interactive mode

# Kernel
kernel-download         # Download kernel source to src/
kernel-patch            # Apply patches
kernel-config           # Generate .config
kernel-menuconfig       # Interactive kernel config
kernel-build            # Compile kernel
kernel-rebuild          # Incremental rebuild
kernel-clean            # Clean kernel build artifacts
kernel-saveconfig       # Export config diff as fragment
kernel-export-patches   # Export kernel modifications as patches

# Rootfs
rootfs-prepare          # Prepare prebuilt rootfs + overlay
rootfs-build            # Buildroot full build
rootfs-rebuild          # Buildroot incremental build
rootfs-menuconfig       # Buildroot interactive config
rootfs-modules          # Inject kernel modules into rootfs
rootfs-clean            # Clean rootfs artifacts

# QEMU
qemu-build              # Compile QEMU from source
qemu-rebuild            # QEMU incremental rebuild
qemu-boot               # Boot QEMU only (skip kernel build)
qemu-debug              # Boot QEMU with GDB server (-s -S)
qemu-export-patches     # Export QEMU modifications as patches

# Debug
debug                   # Launch GDB, connect to QEMU

# Environment
info                    # Show current config
list-boards             # List available boards
list-kernels            # List supported kernel versions for current board
help                    # Show all targets
clean                   # Clean current board artifacts
distclean               # Clean everything + downloaded sources

# CI
boot-test               # Smoke test: build + boot + verify login prompt + exit
```

### Variable System

```makefile
BOARD       ?= arm/vexpress-a9
KERNEL      ?= $(KERNEL_DEFAULT)
KERNEL_SRC  ?= src/linux-$(KERNEL)
ROOTFS_SRC  ?= src/rootfs/$(BOARD_ARCH)
QEMU_SRC    ?= src/qemu
BUILDROOT_SRC ?= src/buildroot
JOBS        ?= $(shell nproc)
QEMU_EXTRA  ?=                          # User-appended QEMU args
```

Config priority: CLI args > env vars > `.linux-lab.conf` > board defaults.

### Internal Structure

Makefile handles config loading and target dispatch only. All logic lives in `scripts/*.sh`.

## 7. TUI Design

### Tool

`dialog` / `whiptail` — pre-installed in container, pure terminal, no external dependencies.

### Main Menu

```
1. Select board and boot
2. Kernel management
3. Rootfs management
4. QEMU management
5. Add new board
6. System info
```

### Board Selection Flow

```
Select arch → Select board → Select kernel version → Confirm → Execute boot
```

### Add New Board Wizard

Interactive guided flow:

1. Select architecture (arm/riscv/x86_64)
2. Input board name
3. Input QEMU machine type, CPU, memory
4. Auto-suggest kernel image name, serial device based on arch
5. Select supported kernel versions (multi-select)
6. Specify defconfig per version
7. Auto-generate `boards/<arch>/<board>/board.mk`, `kernel-<ver>.mk`, `rootfs.mk`
8. Optionally boot immediately

### Implementation

```
scripts/tui/
├── main_menu.sh
├── board_select.sh
├── board_create.sh
├── kernel_menu.sh
├── rootfs_menu.sh
├── qemu_menu.sh
└── utils.sh              # dialog wrapper functions
```

TUI is a frontend to Makefile targets — all actions ultimately call `make xxx`.

## 8. Kernel Source Management

### Download Strategy

```bash
# Default: tarball from kernel.org CDN (fast)
make kernel-download KERNEL=6.6
# → src/linux-6.6/

# Optional: git clone (when full history needed)
make kernel-download KERNEL=6.6 KERNEL_GIT=1
# → git clone --branch v6.6 --depth=1
```

### Out-of-Tree Build

Source and build artifacts separated:

```makefile
KERNEL_OUT := $(OUTPUT_DIR)/$(BOARD)/linux-$(KERNEL)

kernel-build:
    make -C $(KERNEL_SRC) O=$(KERNEL_OUT) ARCH=$(BOARD_ARCH) \
        CROSS_COMPILE=$(CROSS_COMPILE) -j$(JOBS) $(KERNEL_IMAGE)
```

Same source tree can be shared across multiple boards.

### Patch Application Order

```
patches/linux/common/       → All versions
patches/linux/<version>/    → Version specific
patches/linux/<board>/      → Board specific (if exists)
```

### Custom Source Path

```bash
make kernel-build BOARD=arm/vexpress-a9 KERNEL_SRC=/path/to/my-linux
```

## 9. Rootfs Management

### Two Modes

| Mode | Use Case | Format |
|------|----------|--------|
| Prebuilt (Busybox) | Quick boot, teaching | cpio.gz (default) |
| Buildroot | Deep customization | cpio.gz or ext4 |

### Prebuilt Rootfs Contents

- Busybox (statically compiled)
- Minimal `/etc` (inittab, passwd, fstab, rcS)
- Mount points: `/dev`, `/proc`, `/sys`, `/tmp`
- User overlay files from `rootfs/overlay/`

### Kernel Module Injection

```bash
make rootfs-modules BOARD=arm/vexpress-a9 KERNEL=6.6
# Runs modules_install → repacks into rootfs.cpio.gz

make rootfs-modules MODULE_SRC=/path/to/my-driver  # External module
```

### Custom Rootfs Path

```bash
make boot BOARD=arm/vexpress-a9 ROOTFS_SRC=/path/to/my-rootfs
```

## 10. QEMU Boot & Debug

### Parameter Assembly

`scripts/qemu.sh` auto-assembles from board config:

```bash
qemu-system-arm \
    -machine vexpress-a9 \
    -m 512M \
    -kernel output/arm/vexpress-a9/linux-6.6/arch/arm/boot/zImage \
    -dtb output/arm/vexpress-a9/linux-6.6/arch/arm/boot/dts/vexpress-v2p-ca9.dtb \
    -initrd output/arm/vexpress-a9/rootfs/rootfs.cpio.gz \
    -append "console=ttyAMA0 rdinit=/sbin/init" \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net-device,netdev=net0 \
    -nographic
```

### Pre-boot Validation

Before launching QEMU, auto-check:

1. Kernel image exists → suggest `make kernel-build`
2. Rootfs exists → suggest `make rootfs-prepare`
3. QEMU binary available → suggest `make qemu-build`
4. DTB exists (if needed) → suggest checking config

### GDB Debug Workflow

```
Terminal 1:                          Terminal 2:
$ make qemu-debug                   $ make debug
  → qemu ... -s -S                    → gdb-multiarch vmlinux
  → waiting for GDB...                → target remote :1234
```

## 11. CNB Integration

### .cnb.yml Pipeline

Triggers on Dockerfile/toolchain/rootfs changes:

1. **build-image**: Multi-stage Docker build
2. **test-image**: Verify toolchains + QEMU + smoke test boot
3. **push-image**: Push to CNB registry

### .ide.yaml (Cloud IDE Config)

```yaml
image: registry.cnb.cool/${CNB_OWNER}/linux-lab:latest
resources:
  cpu: 4
  memory: 8Gi
  disk: 50Gi
ports:
  - port: 1234
    name: gdb
  - port: 2222
    name: ssh
```

### CNB Environment Detection

`scripts/cnb-detect.sh` auto-detects CNB IDE and applies:

- Disable KVM
- Force cpio rootfs format
- Use user mode networking

### Welcome Script

Runs on IDE startup, displays quick-start guide and environment status.

### Smoke Test

```makefile
boot-test:  # Build kernel + boot QEMU + wait for "login:" + auto-exit (120s timeout)
```
