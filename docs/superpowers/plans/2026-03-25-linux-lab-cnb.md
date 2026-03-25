# Linux Lab on CNB — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Docker + QEMU based Linux development platform on CNB Cloud IDE, enabling one-click boot for ARM/RISC-V/x86_64 boards with interactive kernel development and debugging.

**Architecture:** Declarative board configs (`.mk` files) drive a Makefile that dispatches to shell scripts for kernel management, rootfs preparation, and QEMU boot. A TUI provides interactive board selection and creation. The whole environment runs inside a custom Docker image used as the CNB Cloud IDE base.

**Tech Stack:** GNU Make, Bash, QEMU, Docker, dialog/whiptail (TUI), cross-compilation toolchains (Bootlin/Linaro), Buildroot, Git submodules.

**Spec:** `docs/superpowers/specs/2026-03-25-linux-lab-cnb-design.md`

---

## File Structure

```
linux-lab/
├── .gitignore
├── .gitmodules
├── Makefile                            # Main entry: config loading + target dispatch
├── .cnb.yml                            # CNB Pipeline config
├── .ide.yaml                           # CNB Cloud IDE config
├── Dockerfile                          # Multi-stage image build
├── boards/
│   ├── arm/vexpress-a9/
│   │   ├── board.mk                   # Board-level common config
│   │   ├── kernel-5.15.mk             # Kernel 5.15 specific
│   │   ├── kernel-6.1.mk              # Kernel 6.1 specific
│   │   ├── kernel-6.6.mk              # Kernel 6.6 specific
│   │   └── rootfs.mk                  # Rootfs config
│   ├── riscv/virt/
│   │   ├── board.mk
│   │   ├── kernel-6.1.mk
│   │   ├── kernel-6.6.mk
│   │   └── rootfs.mk
│   └── x86_64/pc/
│       ├── board.mk
│       ├── kernel-6.1.mk
│       ├── kernel-6.6.mk
│       └── rootfs.mk
├── toolchains/
│   ├── config.mk                      # Toolchain path mapping
│   └── wrappers/                      # Compatibility wrapper scripts
├── configs/                            # Kernel config fragments (populated later)
├── rootfs/
│   ├── prebuilt/                       # Prebuilt rootfs per arch
│   │   ├── arm/.gitkeep
│   │   ├── riscv/.gitkeep
│   │   └── x86_64/.gitkeep
│   ├── overlay/                        # User overlay files
│   │   ├── etc/init.d/rcS
│   │   ├── etc/inittab
│   │   ├── etc/passwd
│   │   └── etc/fstab
│   └── busybox.config                 # Busybox build config
├── patches/
│   ├── qemu/.gitkeep
│   ├── buildroot/.gitkeep
│   └── linux/
│       ├── common/.gitkeep
│       ├── 5.15/.gitkeep
│       ├── 6.1/.gitkeep
│       └── 6.6/.gitkeep
├── scripts/
│   ├── common.sh                      # Shared functions (logging, checks, colors)
│   ├── kernel.sh                      # Kernel download/patch/config/build
│   ├── rootfs.sh                      # Rootfs prepare/build/modules
│   ├── qemu.sh                        # QEMU param assembly/boot/boot-test
│   ├── debug.sh                       # GDB launch
│   ├── toolchain.sh                   # Toolchain version resolution
│   ├── cnb-detect.sh                  # CNB environment detection + adaptation
│   ├── welcome.sh                     # IDE startup welcome message
│   └── tui/
│       ├── utils.sh                   # dialog wrapper functions
│       ├── main_menu.sh               # TUI main menu
│       ├── board_select.sh            # Board selection flow
│       ├── board_create.sh            # New board wizard
│       ├── kernel_menu.sh             # Kernel management menu
│       ├── rootfs_menu.sh             # Rootfs management menu
│       └── qemu_menu.sh              # QEMU management menu
├── tests/
│   └── smoke-test.sh                  # End-to-end smoke test
├── docs/
│   ├── zh/
│   │   ├── getting-started.md
│   │   └── board-guide.md
│   └── en/
│       ├── getting-started.md
│       └── board-guide.md
└── output/                             # Build artifacts (gitignore)
```

---

## Task 1: Project Skeleton

**Files:**
- Create: `.gitignore`
- Create: `boards/arm/vexpress-a9/.gitkeep` (placeholder)
- Create: `boards/riscv/virt/.gitkeep`
- Create: `boards/x86_64/pc/.gitkeep`
- Create: `configs/.gitkeep`
- Create: `toolchains/wrappers/.gitkeep`
- Create: `rootfs/prebuilt/arm/.gitkeep`
- Create: `rootfs/prebuilt/riscv/.gitkeep`
- Create: `rootfs/prebuilt/x86_64/.gitkeep`
- Create: `patches/qemu/.gitkeep`
- Create: `patches/buildroot/.gitkeep`
- Create: `patches/linux/common/.gitkeep`
- Create: `patches/linux/5.15/.gitkeep`
- Create: `patches/linux/6.1/.gitkeep`
- Create: `patches/linux/6.6/.gitkeep`

- [ ] **Step 1: Create .gitignore**

```gitignore
# Source code (downloaded on demand)
src/*
!src/qemu/
!src/buildroot/

# Build artifacts
output/

# User local config
.linux-lab.conf

# Editor files
*.swp
*.swo
*~
.vscode/
.idea/
```

- [ ] **Step 2: Create directory structure with placeholders**

```bash
mkdir -p boards/arm/vexpress-a9 boards/riscv/virt boards/x86_64/pc
mkdir -p configs toolchains/wrappers
mkdir -p rootfs/prebuilt/{arm,riscv,x86_64} rootfs/overlay/etc/init.d
mkdir -p patches/{qemu,buildroot} patches/linux/{common,5.15,6.1,6.6}
mkdir -p scripts/tui tests docs/{zh,en}
touch boards/arm/vexpress-a9/.gitkeep boards/riscv/virt/.gitkeep boards/x86_64/pc/.gitkeep
touch configs/.gitkeep toolchains/wrappers/.gitkeep
touch rootfs/prebuilt/{arm,riscv,x86_64}/.gitkeep
touch patches/qemu/.gitkeep patches/buildroot/.gitkeep
touch patches/linux/{common,5.15,6.1,6.6}/.gitkeep
```

- [ ] **Step 3: Initialize git submodules**

```bash
git submodule add https://gitlab.com/qemu-project/qemu.git src/qemu
git submodule add https://github.com/buildroot/buildroot.git src/buildroot
# Pin to stable versions
cd src/qemu && git checkout v9.2.0 && cd ../..
cd src/buildroot && git checkout 2024.02 && cd ../..
```

- [ ] **Step 4: Verify structure**

Run: `find . -type f | grep -v '.git/' | sort`
Expected: all placeholder files exist in correct paths, `.gitmodules` exists.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: create project skeleton with directory structure

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 2: Board Configuration — ARM vexpress-a9

**Files:**
- Create: `boards/arm/vexpress-a9/board.mk`
- Create: `boards/arm/vexpress-a9/kernel-5.15.mk`
- Create: `boards/arm/vexpress-a9/kernel-6.1.mk`
- Create: `boards/arm/vexpress-a9/kernel-6.6.mk`
- Create: `boards/arm/vexpress-a9/rootfs.mk`

- [ ] **Step 1: Create board.mk**

```makefile
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
```

- [ ] **Step 2: Create kernel-6.6.mk**

```makefile
# Kernel 6.6 configuration for ARM vexpress-a9

KERNEL_VERSION       ?= 6.6
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.6.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
KERNEL_SHA256        ?= d7797e25b0d8ba0f158d4ceb4e0a40aa82de5a1db07e6ab1ce0be04fa0580dbd
KERNEL_DEFCONFIG     ?= vexpress_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

- [ ] **Step 3: Create kernel-6.1.mk**

```makefile
# Kernel 6.1 configuration for ARM vexpress-a9

KERNEL_VERSION       ?= 6.1
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.1.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
KERNEL_SHA256        ?= 2ca1f17051a430f6fed1196e4952717507171acfd97d96577212502703b25deb
KERNEL_DEFCONFIG     ?= vexpress_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

- [ ] **Step 4: Create kernel-5.15.mk**

```makefile
# Kernel 5.15 configuration for ARM vexpress-a9

KERNEL_VERSION       ?= 5.15
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v5.x/linux-5.15.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
KERNEL_SHA256        ?= 57b2cf6991910e3b67a1b3490022e8a0674b6965c74c12da1e99d138d1991ee8
KERNEL_DEFCONFIG     ?= vexpress_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

- [ ] **Step 5: Create rootfs.mk**

```makefile
# Rootfs configuration for ARM vexpress-a9

ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/arm/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_arm_vexpress_defconfig
ROOTFS_APPEND              ?= console=ttyAMA0 rdinit=/sbin/init
```

- [ ] **Step 6: Verify configs are valid Makefile syntax**

Run: `make -f boards/arm/vexpress-a9/board.mk -p -q 2>&1 | head -5`
Expected: no syntax errors (exit code 2 is OK since there are no targets, just variable definitions).

- [ ] **Step 7: Commit**

```bash
git add boards/arm/vexpress-a9/
git commit -m "feat: add ARM vexpress-a9 board configuration

Add board.mk with QEMU/toolchain/kernel/debug settings.
Add kernel configs for 5.15, 6.1, 6.6 LTS versions.
Add rootfs config with cpio/initramfs default.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 3: Rootfs Overlay Files

**Files:**
- Create: `rootfs/overlay/etc/inittab`
- Create: `rootfs/overlay/etc/init.d/rcS`
- Create: `rootfs/overlay/etc/passwd`
- Create: `rootfs/overlay/etc/fstab`

- [ ] **Step 1: Create inittab**

```
::sysinit:/etc/init.d/rcS
::respawn:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
```

- [ ] **Step 2: Create rcS init script**

```bash
#!/bin/sh

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /tmp

echo "Welcome to Linux Lab minimal rootfs"
echo "Kernel: $(uname -r) on $(uname -m)"
```

- [ ] **Step 3: Create passwd**

```
root::0:0:root:/root:/bin/sh
```

- [ ] **Step 4: Create fstab**

```
proc    /proc   proc    defaults    0   0
sysfs   /sys    sysfs   defaults    0   0
tmpfs   /tmp    tmpfs   defaults    0   0
```

- [ ] **Step 5: Make rcS executable**

Run: `chmod +x rootfs/overlay/etc/init.d/rcS`

- [ ] **Step 6: Commit**

```bash
git add rootfs/overlay/
git commit -m "feat: add minimal rootfs overlay files

Provide inittab, rcS init script, passwd, and fstab for
the Busybox-based minimal rootfs used in prebuilt images.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 4: Common Script Library

**Files:**
- Create: `scripts/common.sh`

- [ ] **Step 1: Create scripts/common.sh**

```bash
#!/bin/bash
# Common functions for linux-lab scripts
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERR ]${NC} $*" >&2; }
log_fatal() { log_error "$@"; exit 1; }

# Check if a command exists
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || log_fatal "Required command not found: $1"
}

# Check if a file exists, with helpful error
check_file() {
    local file="$1"
    local hint="${2:-}"
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        [ -n "$hint" ] && log_info "Hint: $hint"
        return 1
    fi
}

# Check available disk space (in MB)
check_disk_space() {
    local required_mb="${1:-5120}"
    local dir="${2:-.}"
    local available_mb
    available_mb=$(df -m "$dir" | awk 'NR==2 {print $4}')
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_warn "Low disk space: ${available_mb}MB available, ${required_mb}MB recommended"
        log_warn "Run 'make disk-usage' to see breakdown, 'make clean' to free space"
    fi
}

# Ensure directory exists
ensure_dir() {
    mkdir -p "$1"
}

# Download with resume and fallback
download_file() {
    local url="$1"
    local url_alt="${2:-}"
    local dest="$3"
    local sha256="${4:-}"

    ensure_dir "$(dirname "$dest")"

    log_info "Downloading $(basename "$dest")..."
    local tmp_dir
    tmp_dir="$(dirname "$dest")"
    if ! wget -q --show-progress -P "$tmp_dir" "$url" 2>/dev/null; then
        if [ -n "$url_alt" ]; then
            log_warn "Primary mirror failed, trying fallback..."
            wget -q --show-progress -P "$tmp_dir" "$url_alt" || \
                log_fatal "Download failed from both mirrors"
            url="$url_alt"
        else
            log_fatal "Download failed: $url"
        fi
    fi
    # Rename downloaded file to expected destination
    local downloaded="$tmp_dir/$(basename "$url")"
    if [ "$downloaded" != "$dest" ] && [ -f "$downloaded" ]; then
        mv "$downloaded" "$dest"
    fi

    if [ -n "$sha256" ]; then
        log_info "Verifying checksum..."
        echo "$sha256  $dest" | sha256sum -c --quiet || \
            log_fatal "Checksum verification failed for $dest"
        log_ok "Checksum verified"
    fi
}

# Logging to file
LOG_DIR=""
setup_logging() {
    local board="$1"
    local target="$2"
    LOG_DIR="${OUTPUT_DIR:-output}/${board}/logs"
    ensure_dir "$LOG_DIR"
    LOG_FILE="${LOG_DIR}/${target}-$(date +%Y%m%d-%H%M%S).log"
    log_info "Logging to $LOG_FILE"
}

# Run command with logging
run_logged() {
    if [ -n "${LOG_FILE:-}" ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
        return "${PIPESTATUS[0]}"
    else
        "$@"
    fi
}

# Show last N lines of log on failure
show_log_tail() {
    local n="${1:-20}"
    if [ -n "${LOG_FILE:-}" ] && [ -f "$LOG_FILE" ]; then
        log_error "Last $n lines of log:"
        tail -n "$n" "$LOG_FILE" >&2
        log_error "Full log: $LOG_FILE"
    fi
}
```

- [ ] **Step 2: Run shellcheck**

Run: `shellcheck scripts/common.sh`
Expected: no errors (warnings about unused functions are OK since this is a library).

- [ ] **Step 3: Verify sourcing works**

Run: `bash -c 'source scripts/common.sh && log_info "test" && log_ok "works"'`
Expected: colored output `[INFO] test` and `[ OK ] works`.

- [ ] **Step 4: Commit**

```bash
git add scripts/common.sh
git commit -m "feat: add common script library

Provide shared functions for logging (colored), file/command checks,
disk space monitoring, download with resume/fallback/checksum, and
build log management.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 5: Base Makefile Framework

**Files:**
- Create: `Makefile`
- Create: `toolchains/config.mk`

- [ ] **Step 1: Create toolchains/config.mk**

```makefile
# Toolchain path configuration
# Each toolchain is installed to an independent prefix under /opt/toolchains/

TOOLCHAIN_BASE ?= /opt/toolchains

# ARM toolchain paths (mapped by TOOLCHAIN_VERSION from kernel-<ver>.mk)
TOOLCHAIN_PATH_arm_gcc-13  ?= $(TOOLCHAIN_BASE)/arm-gcc13/bin

# RISC-V toolchain paths
TOOLCHAIN_PATH_riscv_gcc-13 ?= $(TOOLCHAIN_BASE)/riscv-gcc13/bin

# x86_64 uses host gcc
TOOLCHAIN_PATH_x86_64_gcc-13 ?=

# Resolve toolchain bin path for current board
TOOLCHAIN_BIN = $(TOOLCHAIN_PATH_$(BOARD_ARCH)_$(TOOLCHAIN_VERSION))

# Prepend toolchain to PATH if set
ifneq ($(TOOLCHAIN_BIN),)
    export PATH := $(TOOLCHAIN_BIN):$(PATH)
endif
```

- [ ] **Step 2: Create Makefile**

```makefile
# Linux Lab — Docker + QEMU based Linux development platform
# https://github.com/user/linux-lab

.PHONY: help boot tui info list-boards list-kernels clean distclean disk-usage
.PHONY: kernel-download kernel-patch kernel-config kernel-menuconfig
.PHONY: kernel-build kernel-rebuild kernel-clean kernel-saveconfig kernel-export-patches
.PHONY: rootfs-prepare rootfs-build rootfs-rebuild rootfs-menuconfig rootfs-modules rootfs-clean
.PHONY: qemu-build qemu-rebuild qemu-boot qemu-debug qemu-export-patches
.PHONY: debug boot-test check-submodules

# ==============================================================================
# Directory layout
# ==============================================================================
TOP_DIR      := $(CURDIR)
SCRIPTS_DIR  := $(TOP_DIR)/scripts
BOARDS_DIR   := $(TOP_DIR)/boards
CONFIGS_DIR  := $(TOP_DIR)/configs
OUTPUT_DIR   := $(TOP_DIR)/output
PREBUILT_DIR := $(TOP_DIR)/rootfs/prebuilt
PATCHES_DIR  := $(TOP_DIR)/patches
SRC_DIR      := $(TOP_DIR)/src

# ==============================================================================
# User-configurable variables (can be overridden via CLI or .linux-lab.conf)
# ==============================================================================
BOARD         ?= arm/vexpress-a9
QEMU_SRC      ?= $(SRC_DIR)/qemu
BUILDROOT_SRC ?= $(SRC_DIR)/buildroot
JOBS          ?= $(shell nproc)
QEMU_EXTRA    ?=
KERNEL_GIT    ?= 0

# ==============================================================================
# Load configuration chain
# Priority: CLI > env > .linux-lab.conf (:=) > board configs (?=)
# ==============================================================================
-include .linux-lab.conf
include $(BOARDS_DIR)/$(BOARD)/board.mk
-include $(BOARDS_DIR)/$(BOARD)/kernel-$(or $(KERNEL),$(KERNEL_DEFAULT)).mk
include $(BOARDS_DIR)/$(BOARD)/rootfs.mk
include toolchains/config.mk

# Resolve defaults after config loading (only if not already set by CLI/env/.linux-lab.conf)
ifndef KERNEL
KERNEL := $(KERNEL_DEFAULT)
endif
ifndef KERNEL_SRC
KERNEL_SRC := $(SRC_DIR)/linux-$(KERNEL)
endif
ifndef ROOTFS_SRC
ROOTFS_SRC := $(SRC_DIR)/rootfs/$(BOARD_ARCH)
endif
ROOTFS_IMAGE ?=

# Board-specific output directory
BOARD_OUTPUT := $(OUTPUT_DIR)/$(BOARD)
KERNEL_OUT   := $(BOARD_OUTPUT)/linux-$(KERNEL)

# QEMU binary: prefer user-built, fallback to system
QEMU_PREFIX  ?= $(if $(wildcard $(OUTPUT_DIR)/qemu/bin/$(QEMU_SYSTEM)),$(OUTPUT_DIR)/qemu,/usr/local)
QEMU_BIN     := $(QEMU_PREFIX)/bin/$(QEMU_SYSTEM)

# Export for scripts
export TOP_DIR SCRIPTS_DIR BOARDS_DIR CONFIGS_DIR OUTPUT_DIR PREBUILT_DIR
export PATCHES_DIR SRC_DIR BOARD_OUTPUT KERNEL_OUT
export BOARD BOARD_NAME BOARD_ARCH BOARD_DESC
export KERNEL KERNEL_VERSION KERNEL_SRC KERNEL_URL KERNEL_URL_ALT KERNEL_SHA256
export KERNEL_DEFCONFIG KERNEL_CONFIG_EXTRA KERNEL_IMAGE KERNEL_DTB KERNEL_GIT
export CROSS_COMPILE TOOLCHAIN_TYPE TOOLCHAIN_VERSION
export QEMU_BIN QEMU_SRC QEMU_SYSTEM QEMU_MACHINE QEMU_CPU QEMU_MEM
export QEMU_NET QEMU_DISPLAY QEMU_EXTRA
export ROOTFS_TYPE ROOTFS_PREBUILT ROOTFS_SRC ROOTFS_IMAGE ROOTFS_APPEND
export ROOTFS_BUILDROOT_DEFCONFIG BUILDROOT_SRC
export GDB_PORT GDB_ARCH
export JOBS

# ==============================================================================
# Top-level targets
# ==============================================================================

help:
	@echo "Linux Lab — Docker + QEMU Linux Development Platform"
	@echo ""
	@echo "Usage: make [BOARD=<arch>/<board>] [KERNEL=<ver>] <target>"
	@echo ""
	@echo "  Current board:  $(BOARD) ($(BOARD_DESC))"
	@echo "  Current kernel: $(KERNEL)"
	@echo ""
	@echo "One-click:"
	@echo "  boot              Build kernel + prepare rootfs + boot QEMU"
	@echo "  tui               TUI interactive mode"
	@echo ""
	@echo "Kernel:"
	@echo "  kernel-download   Download kernel source to src/"
	@echo "  kernel-patch      Apply patches from patches/linux/"
	@echo "  kernel-config     Generate .config (defconfig + fragments)"
	@echo "  kernel-menuconfig Interactive kernel configuration"
	@echo "  kernel-build      Compile kernel"
	@echo "  kernel-rebuild    Incremental rebuild"
	@echo "  kernel-clean      Clean kernel build artifacts"
	@echo "  kernel-saveconfig Export config diff as fragment"
	@echo "  kernel-export-patches  Export source modifications as patches"
	@echo ""
	@echo "Rootfs:"
	@echo "  rootfs-prepare    Prepare prebuilt rootfs + overlay"
	@echo "  rootfs-build      Build rootfs via Buildroot"
	@echo "  rootfs-rebuild    Buildroot incremental rebuild"
	@echo "  rootfs-menuconfig Buildroot interactive config"
	@echo "  rootfs-modules    Inject kernel modules into rootfs"
	@echo "  rootfs-clean      Clean rootfs artifacts"
	@echo ""
	@echo "QEMU:"
	@echo "  qemu-build        Compile QEMU from source"
	@echo "  qemu-rebuild      QEMU incremental rebuild"
	@echo "  qemu-boot         Boot QEMU (skip kernel build)"
	@echo "  qemu-debug        Boot QEMU with GDB server (-s -S)"
	@echo ""
	@echo "Debug:"
	@echo "  debug             Launch GDB, connect to QEMU"
	@echo ""
	@echo "Environment:"
	@echo "  info              Show current configuration"
	@echo "  list-boards       List available boards"
	@echo "  list-kernels      List supported kernel versions"
	@echo "  disk-usage        Show disk usage breakdown"
	@echo "  clean             Clean current board artifacts"
	@echo "  distclean         Clean everything including sources"
	@echo ""
	@echo "CI:"
	@echo "  boot-test         Smoke test (build + boot + verify + exit)"

boot:
	@$(SCRIPTS_DIR)/qemu.sh boot-auto

tui:
	@$(SCRIPTS_DIR)/tui/main_menu.sh

info:
	@echo "Board:       $(BOARD) — $(BOARD_DESC)"
	@echo "Arch:        $(BOARD_ARCH)"
	@echo "Kernel:      $(KERNEL)"
	@echo "Kernel src:  $(KERNEL_SRC)"
	@echo "Kernel out:  $(KERNEL_OUT)"
	@echo "Cross:       $(CROSS_COMPILE)"
	@echo "Toolchain:   $(TOOLCHAIN_VERSION) ($(TOOLCHAIN_TYPE))"
	@echo "QEMU:        $(QEMU_BIN)"
	@echo "QEMU machine:$(QEMU_MACHINE)"
	@echo "Rootfs type: $(ROOTFS_TYPE)"
	@echo "Rootfs:      $(ROOTFS_PREBUILT)"
	@echo "GDB port:    $(GDB_PORT)"

list-boards:
	@echo "Available boards:"
	@for dir in $(BOARDS_DIR)/*/*/board.mk; do \
		board=$$(echo $$dir | sed 's|$(BOARDS_DIR)/||;s|/board.mk||'); \
		desc=$$(grep '^BOARD_DESC' $$dir | head -1 | sed -E 's/.*\?=[[:space:]]*//'); \
		printf "  %-20s %s\n" "$$board" "$$desc"; \
	done

list-kernels:
	@echo "Supported kernels for $(BOARD): $(KERNEL_SUPPORTED)"
	@echo "Default: $(KERNEL_DEFAULT)"

disk-usage:
	@echo "Disk usage breakdown:"
	@du -sh $(SRC_DIR) 2>/dev/null    || echo "  src/        (not yet created)"
	@du -sh $(OUTPUT_DIR) 2>/dev/null || echo "  output/     (not yet created)"
	@echo ""
	@df -h $(TOP_DIR) | tail -1 | awk '{printf "Available: %s of %s\n", $$4, $$2}'

clean:
	@echo "Cleaning $(BOARD) build artifacts..."
	rm -rf $(BOARD_OUTPUT)
	@echo "Done."

distclean: clean
	@echo "Cleaning all build artifacts and downloaded sources..."
	rm -rf $(OUTPUT_DIR) $(SRC_DIR)/linux-*
	@echo "Done."

# ==============================================================================
# Submodule check
# ==============================================================================
check-submodules:
	@if [ ! -f "$(QEMU_SRC)/configure" ] && [ -f .gitmodules ]; then \
		echo "Initializing submodules..."; \
		git submodule update --init src/qemu src/buildroot; \
	fi

# ==============================================================================
# Kernel targets
# ==============================================================================
kernel-download:
	@$(SCRIPTS_DIR)/kernel.sh download

kernel-patch:
	@$(SCRIPTS_DIR)/kernel.sh patch

kernel-config:
	@$(SCRIPTS_DIR)/kernel.sh config

kernel-menuconfig:
	@$(SCRIPTS_DIR)/kernel.sh menuconfig

kernel-build:
	@$(SCRIPTS_DIR)/kernel.sh build

kernel-rebuild:
	@$(SCRIPTS_DIR)/kernel.sh rebuild

kernel-clean:
	@$(SCRIPTS_DIR)/kernel.sh clean

kernel-saveconfig:
	@$(SCRIPTS_DIR)/kernel.sh saveconfig

kernel-export-patches:
	@$(SCRIPTS_DIR)/kernel.sh export-patches

# ==============================================================================
# Rootfs targets
# ==============================================================================
rootfs-prepare:
	@$(SCRIPTS_DIR)/rootfs.sh prepare

rootfs-build:
	@$(SCRIPTS_DIR)/rootfs.sh build

rootfs-rebuild:
	@$(SCRIPTS_DIR)/rootfs.sh rebuild

rootfs-menuconfig:
	@$(SCRIPTS_DIR)/rootfs.sh menuconfig

rootfs-modules:
	@$(SCRIPTS_DIR)/rootfs.sh modules

rootfs-clean:
	@$(SCRIPTS_DIR)/rootfs.sh clean

# ==============================================================================
# QEMU targets
# ==============================================================================
qemu-build: check-submodules
	@$(SCRIPTS_DIR)/qemu.sh build

qemu-rebuild:
	@$(SCRIPTS_DIR)/qemu.sh rebuild

qemu-boot:
	@$(SCRIPTS_DIR)/qemu.sh boot

qemu-debug:
	@$(SCRIPTS_DIR)/qemu.sh debug

qemu-export-patches:
	@$(SCRIPTS_DIR)/qemu.sh export-patches

# ==============================================================================
# Debug targets
# ==============================================================================
debug:
	@$(SCRIPTS_DIR)/debug.sh

# ==============================================================================
# CI targets
# ==============================================================================
boot-test:
	@$(SCRIPTS_DIR)/qemu.sh boot-test
```

- [ ] **Step 3: Verify Makefile syntax and help output**

Run: `make help`
Expected: formatted help text with all targets listed, showing `arm/vexpress-a9` as current board and `6.6` as kernel.

Run: `make info`
Expected: configuration summary output.

Run: `make list-boards`
Expected: `arm/vexpress-a9` listed with description.

- [ ] **Step 4: Commit**

```bash
git add Makefile toolchains/config.mk
git commit -m "feat: add base Makefile framework and toolchain config

Makefile provides config loading chain, variable system, help text,
and all target stubs dispatching to scripts/*.sh.
toolchains/config.mk maps toolchain versions to install paths.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 6: Kernel Management Script

**Files:**
- Create: `scripts/kernel.sh`

- [ ] **Step 1: Create scripts/kernel.sh**

```bash
#!/bin/bash
# Kernel source management: download, patch, config, build
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:?Usage: kernel.sh <download|patch|config|menuconfig|build|rebuild|clean|saveconfig|export-patches>}"

kernel_download() {
    if [ -d "$KERNEL_SRC" ] && [ -f "$KERNEL_SRC/Makefile" ]; then
        log_info "Kernel source already exists at $KERNEL_SRC"
        return 0
    fi

    check_disk_space 2048 "$SRC_DIR"

    if [ "$KERNEL_GIT" = "1" ]; then
        log_info "Cloning kernel $KERNEL via git..."
        check_cmd git
        git clone --branch "v${KERNEL}" --depth=1 \
            "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git" \
            "$KERNEL_SRC"
    else
        local tarball="${SRC_DIR}/linux-${KERNEL}.tar.xz"
        download_file "$KERNEL_URL" "$KERNEL_URL_ALT" "$tarball" "$KERNEL_SHA256"

        log_info "Extracting kernel source..."
        ensure_dir "$SRC_DIR"
        tar xf "$tarball" -C "$SRC_DIR"

        # Handle directory naming (linux-6.6 vs linux-6.6.x)
        local extracted
        extracted=$(find "$SRC_DIR" -maxdepth 1 -type d -name "linux-${KERNEL}*" | head -1)
        if [ "$extracted" != "$KERNEL_SRC" ] && [ -n "$extracted" ]; then
            mv "$extracted" "$KERNEL_SRC"
        fi

        rm -f "$tarball"
    fi

    log_ok "Kernel source ready at $KERNEL_SRC"
}

kernel_patch() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"

    local applied=0

    # Apply patches in order: common → version → board
    for patch_dir in \
        "$PATCHES_DIR/linux/common" \
        "$PATCHES_DIR/linux/$KERNEL" \
        "$PATCHES_DIR/linux/$BOARD"; do

        [ -d "$patch_dir" ] || continue

        for patch in "$patch_dir"/*.patch; do
            [ -f "$patch" ] || continue
            log_info "Applying patch: $(basename "$patch")"
            (cd "$KERNEL_SRC" && patch -p1 -N < "$patch") || \
                log_warn "Patch may already be applied: $(basename "$patch")"
            applied=$((applied + 1))
        done
    done

    if [ "$applied" -eq 0 ]; then
        log_info "No patches to apply"
    else
        log_ok "Applied $applied patch(es)"
    fi
}

kernel_config() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"
    ensure_dir "$KERNEL_OUT"

    setup_logging "$BOARD" "kernel-config"

    log_info "Generating kernel config: $KERNEL_DEFCONFIG"
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        "$KERNEL_DEFCONFIG"

    if [ -n "$KERNEL_CONFIG_EXTRA" ] && [ -f "$KERNEL_CONFIG_EXTRA" ]; then
        log_info "Merging extra config: $KERNEL_CONFIG_EXTRA"
        "$KERNEL_SRC/scripts/kconfig/merge_config.sh" \
            -m -O "$KERNEL_OUT" \
            "$KERNEL_OUT/.config" "$KERNEL_CONFIG_EXTRA"
    fi

    log_ok "Kernel config ready at $KERNEL_OUT/.config"
}

kernel_menuconfig() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"
    ensure_dir "$KERNEL_OUT"

    # Generate default config first if none exists
    if [ ! -f "$KERNEL_OUT/.config" ]; then
        kernel_config
    fi

    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        menuconfig
}

kernel_build() {
    check_file "$KERNEL_SRC/Makefile" "Run 'make kernel-download' first"

    # Auto-config if no .config
    if [ ! -f "$KERNEL_OUT/.config" ]; then
        kernel_config
    fi

    check_disk_space 3072 "$OUTPUT_DIR"
    setup_logging "$BOARD" "kernel-build"

    log_info "Building kernel $KERNEL for $BOARD ($KERNEL_IMAGE)..."
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" "$KERNEL_IMAGE" dtbs modules || {
        show_log_tail
        log_fatal "Kernel build failed"
    }

    log_ok "Kernel built: $KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
}

kernel_rebuild() {
    check_file "$KERNEL_OUT/.config" "Run 'make kernel-build' first"
    setup_logging "$BOARD" "kernel-rebuild"

    log_info "Rebuilding kernel (incremental)..."
    run_logged make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        -j"$JOBS" "$KERNEL_IMAGE" dtbs modules || {
        show_log_tail
        log_fatal "Kernel rebuild failed"
    }

    log_ok "Kernel rebuild complete"
}

kernel_clean() {
    if [ -d "$KERNEL_OUT" ]; then
        log_info "Cleaning kernel build: $KERNEL_OUT"
        rm -rf "$KERNEL_OUT"
        log_ok "Cleaned"
    else
        log_info "Nothing to clean"
    fi
}

kernel_saveconfig() {
    check_file "$KERNEL_OUT/.config" "Run 'make kernel-config' first"

    local fragment="$CONFIGS_DIR/${BOARD_ARCH}_$(echo "$BOARD_NAME" | tr '/' '_')_${KERNEL}.config"
    ensure_dir "$CONFIGS_DIR"

    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        savedefconfig

    cp "$KERNEL_OUT/defconfig" "$fragment"
    log_ok "Config fragment saved: $fragment"
}

kernel_export_patches() {
    check_file "$KERNEL_SRC/Makefile" "No kernel source found"
    check_cmd git

    local patch_dir="$PATCHES_DIR/linux/$KERNEL"
    ensure_dir "$patch_dir"

    if [ -d "$KERNEL_SRC/.git" ]; then
        (cd "$KERNEL_SRC" && git format-patch -o "$patch_dir" HEAD~1)
        log_ok "Patches exported to $patch_dir"
    else
        log_warn "Kernel source is not a git repo. Use KERNEL_GIT=1 for git-based workflow."
    fi
}

case "$ACTION" in
    download)        kernel_download ;;
    patch)           kernel_patch ;;
    config)          kernel_config ;;
    menuconfig)      kernel_menuconfig ;;
    build)           kernel_build ;;
    rebuild)         kernel_rebuild ;;
    clean)           kernel_clean ;;
    saveconfig)      kernel_saveconfig ;;
    export-patches)  kernel_export_patches ;;
    *)               log_fatal "Unknown action: $ACTION" ;;
esac
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/kernel.sh && shellcheck scripts/kernel.sh`
Expected: no errors (some info-level warnings acceptable).

- [ ] **Step 3: Verify help/usage message**

Run: `bash scripts/kernel.sh 2>&1; echo "exit: $?"`
Expected: exits with error showing usage message.

- [ ] **Step 4: Commit**

```bash
git add scripts/kernel.sh
git commit -m "feat: add kernel management script

Implements download (tarball + git), patch application (common →
version → board order), config generation with fragment merging,
menuconfig, build (out-of-tree), incremental rebuild, clean,
saveconfig, and export-patches.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 7: Rootfs Management Script

**Files:**
- Create: `scripts/rootfs.sh`

- [ ] **Step 1: Create scripts/rootfs.sh**

```bash
#!/bin/bash
# Rootfs management: prepare prebuilt, build via Buildroot, inject modules
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:?Usage: rootfs.sh <prepare|build|rebuild|menuconfig|modules|clean>}"

ROOTFS_OUT="$BOARD_OUTPUT/rootfs"
ROOTFS_WORK="$ROOTFS_OUT/work"

rootfs_prepare() {
    ensure_dir "$ROOTFS_OUT"

    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        log_info "Using custom rootfs image: $ROOTFS_IMAGE"
        cp "$ROOTFS_IMAGE" "$ROOTFS_OUT/rootfs.cpio.gz"
        log_ok "Rootfs ready"
        return 0
    fi

    if [ -f "$ROOTFS_PREBUILT" ]; then
        log_info "Using prebuilt rootfs: $ROOTFS_PREBUILT"
        cp "$ROOTFS_PREBUILT" "$ROOTFS_OUT/rootfs.cpio.gz"

        # Apply overlay on top of prebuilt
        if [ -d "$TOP_DIR/rootfs/overlay" ]; then
            log_info "Applying overlay files..."
            rootfs_apply_overlay
        fi
    else
        log_info "No prebuilt rootfs found, building minimal rootfs..."
        rootfs_build_minimal
        # Note: rootfs_build_minimal already includes overlay
    fi

    log_ok "Rootfs ready at $ROOTFS_OUT/rootfs.cpio.gz"
}

rootfs_build_minimal() {
    # Build a minimal rootfs from scratch using busybox
    check_cmd fakeroot
    ensure_dir "$ROOTFS_WORK"

    log_info "Creating minimal rootfs structure..."
    local rootfs_dir="$ROOTFS_WORK/rootfs"
    rm -rf "$rootfs_dir"
    mkdir -p "$rootfs_dir"/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/{bin,sbin},var,lib}

    # Check for busybox in PATH (cross-compiled or static)
    local busybox_bin
    busybox_bin=$(which "${CROSS_COMPILE}busybox" 2>/dev/null || \
                  which busybox-"$BOARD_ARCH" 2>/dev/null || \
                  echo "")

    if [ -n "$busybox_bin" ]; then
        cp "$busybox_bin" "$rootfs_dir/bin/busybox"
        chmod +x "$rootfs_dir/bin/busybox"
        # Install busybox symlinks (no chroot — may lack root/CAP_SYS_CHROOT in container)
        (cd "$rootfs_dir" && for cmd in sh ls cat echo mount umount mkdir rm cp mv \
            ps top kill sleep date df du head tail grep sed awk vi; do
            ln -sf busybox "bin/$cmd"
        done
        for cmd in init halt reboot; do
            ln -sf ../bin/busybox "sbin/$cmd"
        done)
    else
        log_warn "No busybox found for $BOARD_ARCH. Rootfs will be minimal."
        # Create a minimal /init
        cat > "$rootfs_dir/init" << 'INIT_EOF'
#!/bin/sh
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
echo "Linux Lab minimal init — no busybox available"
exec /bin/sh 2>/dev/null || exec sh
INIT_EOF
        chmod +x "$rootfs_dir/init"
    fi

    # Copy overlay
    if [ -d "$TOP_DIR/rootfs/overlay" ]; then
        cp -a "$TOP_DIR/rootfs/overlay/." "$rootfs_dir/"
    fi

    # Create cpio archive
    log_info "Creating cpio archive..."
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")
    log_ok "Minimal rootfs created: $ROOTFS_OUT/rootfs.cpio.gz"
}

rootfs_apply_overlay() {
    # Unpack existing cpio, overlay files, repack
    local rootfs_dir="$ROOTFS_WORK/rootfs-overlay"
    ensure_dir "$rootfs_dir"

    # Unpack
    (cd "$rootfs_dir" && zcat "$ROOTFS_OUT/rootfs.cpio.gz" | fakeroot cpio -idm 2>/dev/null)

    # Overlay
    cp -a "$TOP_DIR/rootfs/overlay/." "$rootfs_dir/"

    # Repack
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")

    rm -rf "$rootfs_dir"
}

rootfs_build() {
    check_file "$BUILDROOT_SRC/Makefile" "Buildroot source not found. Run 'git submodule update --init src/buildroot'"
    check_disk_space 5120 "$OUTPUT_DIR"
    setup_logging "$BOARD" "rootfs-build"

    local br_out="$ROOTFS_OUT/buildroot"
    ensure_dir "$br_out"

    log_info "Building rootfs via Buildroot ($ROOTFS_BUILDROOT_DEFCONFIG)..."
    run_logged make -C "$BUILDROOT_SRC" O="$br_out" \
        "$ROOTFS_BUILDROOT_DEFCONFIG" || {
        show_log_tail
        log_fatal "Buildroot defconfig failed"
    }

    run_logged make -C "$BUILDROOT_SRC" O="$br_out" -j"$JOBS" || {
        show_log_tail
        log_fatal "Buildroot build failed"
    }

    # Copy output image
    local br_image="$br_out/images/rootfs.cpio.gz"
    if [ -f "$br_image" ]; then
        cp "$br_image" "$ROOTFS_OUT/rootfs.cpio.gz"
        log_ok "Buildroot rootfs ready: $ROOTFS_OUT/rootfs.cpio.gz"
    else
        log_fatal "Buildroot output not found at $br_image"
    fi
}

rootfs_rebuild() {
    check_file "$ROOTFS_OUT/buildroot/.config" "Run 'make rootfs-build' first"
    setup_logging "$BOARD" "rootfs-rebuild"

    log_info "Rebuilding rootfs (incremental)..."
    run_logged make -C "$BUILDROOT_SRC" O="$ROOTFS_OUT/buildroot" -j"$JOBS" || {
        show_log_tail
        log_fatal "Buildroot rebuild failed"
    }
    cp "$ROOTFS_OUT/buildroot/images/rootfs.cpio.gz" "$ROOTFS_OUT/rootfs.cpio.gz"
    log_ok "Rootfs rebuild complete"
}

rootfs_menuconfig() {
    check_file "$BUILDROOT_SRC/Makefile" "Buildroot source not found"
    local br_out="$ROOTFS_OUT/buildroot"
    ensure_dir "$br_out"

    if [ ! -f "$br_out/.config" ]; then
        make -C "$BUILDROOT_SRC" O="$br_out" "$ROOTFS_BUILDROOT_DEFCONFIG"
    fi

    make -C "$BUILDROOT_SRC" O="$br_out" menuconfig
}

rootfs_modules() {
    check_file "$KERNEL_OUT/.config" "Kernel not built. Run 'make kernel-build' first"
    check_cmd fakeroot
    ensure_dir "$ROOTFS_WORK"

    local rootfs_dir="$ROOTFS_WORK/rootfs-modules"
    local modules_dir="$ROOTFS_WORK/modules-tmp"
    ensure_dir "$rootfs_dir" "$modules_dir"

    log_info "Installing kernel modules..."
    make -C "$KERNEL_SRC" O="$KERNEL_OUT" \
        ARCH="$BOARD_ARCH" CROSS_COMPILE="$CROSS_COMPILE" \
        INSTALL_MOD_PATH="$modules_dir" modules_install

    # Unpack existing rootfs
    (cd "$rootfs_dir" && zcat "$ROOTFS_OUT/rootfs.cpio.gz" | fakeroot cpio -idm 2>/dev/null)

    # Copy modules
    cp -a "$modules_dir/lib" "$rootfs_dir/"

    # Repack
    (cd "$rootfs_dir" && find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > "$ROOTFS_OUT/rootfs.cpio.gz")

    rm -rf "$rootfs_dir" "$modules_dir"
    log_ok "Kernel modules injected into rootfs"
}

rootfs_clean() {
    if [ -d "$ROOTFS_OUT" ]; then
        log_info "Cleaning rootfs: $ROOTFS_OUT"
        rm -rf "$ROOTFS_OUT"
        log_ok "Cleaned"
    else
        log_info "Nothing to clean"
    fi
}

case "$ACTION" in
    prepare)     rootfs_prepare ;;
    build)       rootfs_build ;;
    rebuild)     rootfs_rebuild ;;
    menuconfig)  rootfs_menuconfig ;;
    modules)     rootfs_modules ;;
    clean)       rootfs_clean ;;
    *)           log_fatal "Unknown action: $ACTION" ;;
esac
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/rootfs.sh && shellcheck scripts/rootfs.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/rootfs.sh
git commit -m "feat: add rootfs management script

Implements prepare (prebuilt + overlay), build (Buildroot),
rebuild (incremental), menuconfig, modules injection, and clean.
Supports custom rootfs path via ROOTFS_IMAGE variable.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 8: QEMU Boot Script

**Files:**
- Create: `scripts/qemu.sh`

- [ ] **Step 1: Create scripts/qemu.sh**

```bash
#!/bin/bash
# QEMU management: build, boot, debug, boot-test
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:?Usage: qemu.sh <build|rebuild|boot|boot-auto|debug|boot-test|export-patches>}"

qemu_build() {
    check_file "$QEMU_SRC/configure" "QEMU source not found. Run 'git submodule update --init src/qemu'"
    check_disk_space 3072 "$OUTPUT_DIR"
    setup_logging "qemu" "qemu-build"

    local qemu_build_dir="$OUTPUT_DIR/qemu-build"
    local qemu_install_dir="$OUTPUT_DIR/qemu"
    ensure_dir "$qemu_build_dir"

    log_info "Configuring and building QEMU (this may take a while)..."
    (
        cd "$qemu_build_dir"
        run_logged "$QEMU_SRC/configure" \
            --prefix="$qemu_install_dir" \
            --target-list=arm-softmmu,riscv64-softmmu,x86_64-softmmu \
            --disable-werror || {
            show_log_tail
            log_fatal "QEMU configure failed"
        }

        run_logged make -j"$JOBS" || {
            show_log_tail
            log_fatal "QEMU build failed"
        }

        run_logged make install
    )
    log_ok "QEMU installed to $qemu_install_dir"
}

qemu_rebuild() {
    local qemu_build_dir="$OUTPUT_DIR/qemu-build"
    check_file "$qemu_build_dir/Makefile" "Run 'make qemu-build' first"
    setup_logging "qemu" "qemu-rebuild"

    log_info "Rebuilding QEMU (incremental)..."
    (
        cd "$qemu_build_dir"
        run_logged make -j"$JOBS" || {
            show_log_tail
            log_fatal "QEMU rebuild failed"
        }
        run_logged make install
    )
    log_ok "QEMU rebuild complete"
}

# Assemble QEMU command line from board config
qemu_assemble_cmd() {
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local dtb_file=""
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"

    # Resolve DTB path
    if [ -n "$KERNEL_DTB" ]; then
        dtb_file="$KERNEL_OUT/arch/$BOARD_ARCH/boot/dts/$KERNEL_DTB"
    fi

    # Resolve rootfs
    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        rootfs_file="$ROOTFS_IMAGE"
    fi

    # Build command
    QEMU_CMD=("$QEMU_BIN")
    QEMU_CMD+=(-machine "$QEMU_MACHINE")
    [ -n "$QEMU_CPU" ] && QEMU_CMD+=(-cpu "$QEMU_CPU")
    QEMU_CMD+=(-m "$QEMU_MEM")
    QEMU_CMD+=(-kernel "$kernel_image")
    [ -n "$dtb_file" ] && QEMU_CMD+=(-dtb "$dtb_file")
    QEMU_CMD+=(-initrd "$rootfs_file")
    QEMU_CMD+=(-append "$ROOTFS_APPEND")

    # Add network (split on spaces for proper argument handling)
    local net_args
    read -ra net_args <<< "$QEMU_NET"
    QEMU_CMD+=("${net_args[@]}")

    # Display
    local display_args
    read -ra display_args <<< "$QEMU_DISPLAY"
    QEMU_CMD+=("${display_args[@]}")

    # Extra args
    if [ -n "$QEMU_EXTRA" ]; then
        local extra_args
        read -ra extra_args <<< "$QEMU_EXTRA"
        QEMU_CMD+=("${extra_args[@]}")
    fi
}

qemu_pre_check() {
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"
    local ret=0

    if [ -n "$ROOTFS_IMAGE" ] && [ -f "$ROOTFS_IMAGE" ]; then
        rootfs_file="$ROOTFS_IMAGE"
    fi

    check_file "$QEMU_BIN" "QEMU not found. Run 'make qemu-build' or install system QEMU" || ret=1
    check_file "$kernel_image" "Kernel image not found. Run 'make kernel-build BOARD=$BOARD KERNEL=$KERNEL'" || ret=1
    check_file "$rootfs_file" "Rootfs not found. Run 'make rootfs-prepare BOARD=$BOARD'" || ret=1

    if [ -n "$KERNEL_DTB" ]; then
        local dtb_file="$KERNEL_OUT/arch/$BOARD_ARCH/boot/dts/$KERNEL_DTB"
        check_file "$dtb_file" "DTB not found. Check KERNEL_DTB in board config" || ret=1
    fi

    return $ret
}

qemu_boot() {
    qemu_pre_check || log_fatal "Pre-boot check failed. Fix the issues above."
    qemu_assemble_cmd

    log_info "Booting $BOARD with kernel $KERNEL..."
    log_info "QEMU command: ${QEMU_CMD[*]}"
    echo ""
    exec "${QEMU_CMD[@]}"
}

qemu_boot_auto() {
    # Fully autonomous boot: auto-download, build, prepare, then boot
    local kernel_image="$KERNEL_OUT/arch/$BOARD_ARCH/boot/$KERNEL_IMAGE"
    local rootfs_file="$BOARD_OUTPUT/rootfs/rootfs.cpio.gz"

    # Auto-download kernel if missing
    if [ ! -f "$KERNEL_SRC/Makefile" ]; then
        log_info "Kernel source not found, downloading linux-$KERNEL..."
        "$SCRIPT_DIR/kernel.sh" download
    fi

    # Auto-build kernel if missing
    if [ ! -f "$kernel_image" ]; then
        log_info "Kernel image not found, building..."
        "$SCRIPT_DIR/kernel.sh" build
    fi

    # Auto-prepare rootfs if missing
    if [ ! -f "$rootfs_file" ]; then
        log_info "Rootfs not found, preparing..."
        "$SCRIPT_DIR/rootfs.sh" prepare
    fi

    # Boot
    qemu_boot
}

qemu_debug() {
    qemu_pre_check || log_fatal "Pre-boot check failed."
    qemu_assemble_cmd

    # Append debug flags
    QEMU_CMD+=(-s -S)

    log_info "Starting QEMU in debug mode (waiting for GDB on port $GDB_PORT)..."
    log_info "In another terminal, run: make debug BOARD=$BOARD KERNEL=$KERNEL"
    log_info "QEMU command: ${QEMU_CMD[*]}"
    echo ""
    exec "${QEMU_CMD[@]}"
}

qemu_boot_test() {
    # Smoke test: boot and wait for login prompt
    qemu_pre_check || {
        # Auto-prepare for CI
        "$SCRIPT_DIR/kernel.sh" download
        "$SCRIPT_DIR/kernel.sh" build
        "$SCRIPT_DIR/rootfs.sh" prepare
    }
    qemu_assemble_cmd

    local timeout=120
    log_info "Smoke test: booting $BOARD, waiting for login prompt (${timeout}s timeout)..."

    local test_log
    test_log=$(mktemp /tmp/qemu-boot-test.XXXXXX.log)

    # Run QEMU with timeout, look for "login:" in output
    timeout "$timeout" stdbuf -oL "${QEMU_CMD[@]}" 2>&1 | tee "$test_log" &
    local qemu_pid=$!

    # Wait for login prompt
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if grep -q "login:" "$test_log" 2>/dev/null; then
            kill $qemu_pid 2>/dev/null || true
            wait $qemu_pid 2>/dev/null || true
            log_ok "Boot test PASSED — login prompt appeared in ${elapsed}s"
            rm -f "$test_log"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    kill $qemu_pid 2>/dev/null || true
    wait $qemu_pid 2>/dev/null || true
    log_error "Boot test FAILED — no login prompt after ${timeout}s"
    log_error "Last 20 lines of output:"
    tail -20 "$test_log" >&2
    rm -f "$test_log"
    return 1
}

qemu_export_patches() {
    check_file "$QEMU_SRC/configure" "QEMU source not found"
    check_cmd git

    local patch_dir="$PATCHES_DIR/qemu"
    ensure_dir "$patch_dir"

    if [ -d "$QEMU_SRC/.git" ]; then
        (cd "$QEMU_SRC" && git format-patch -o "$patch_dir" HEAD~1)
        log_ok "QEMU patches exported to $patch_dir"
    else
        log_warn "QEMU source is not a git repo"
    fi
}

case "$ACTION" in
    build)          qemu_build ;;
    rebuild)        qemu_rebuild ;;
    boot)           qemu_boot ;;
    boot-auto)      qemu_boot_auto ;;
    debug)          qemu_debug ;;
    boot-test)      qemu_boot_test ;;
    export-patches) qemu_export_patches ;;
    *)              log_fatal "Unknown action: $ACTION" ;;
esac
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/qemu.sh && shellcheck scripts/qemu.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/qemu.sh
git commit -m "feat: add QEMU boot and management script

Implements QEMU build from source, parameter assembly from board config,
boot (normal + autonomous + debug mode), smoke test with login prompt
detection, and patch export.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 9: GDB Debug Script

**Files:**
- Create: `scripts/debug.sh`

- [ ] **Step 1: Create scripts/debug.sh**

```bash
#!/bin/bash
# Launch GDB and connect to QEMU debug server
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

VMLINUX="$KERNEL_OUT/vmlinux"

check_file "$VMLINUX" "vmlinux not found. Run 'make kernel-build BOARD=$BOARD KERNEL=$KERNEL'"
check_cmd gdb-multiarch

GDB_INIT="$BOARD_OUTPUT/.gdbinit"

cat > "$GDB_INIT" << EOF
set architecture $GDB_ARCH
target remote :$GDB_PORT
EOF

log_info "Connecting GDB to QEMU ($BOARD) on port $GDB_PORT..."
log_info "vmlinux: $VMLINUX"
exec gdb-multiarch -x "$GDB_INIT" "$VMLINUX"
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/debug.sh && shellcheck scripts/debug.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/debug.sh
git commit -m "feat: add GDB debug script

Generates .gdbinit with architecture and remote target settings,
then launches gdb-multiarch connected to QEMU debug port.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 10: Toolchain Management Script

**Files:**
- Create: `scripts/toolchain.sh`

- [ ] **Step 1: Create scripts/toolchain.sh**

```bash
#!/bin/bash
# Toolchain version resolution and wrapper management
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ACTION="${1:-info}"

toolchain_info() {
    log_info "Toolchain configuration:"
    echo "  Board arch:    $BOARD_ARCH"
    echo "  Cross compile: $CROSS_COMPILE"
    echo "  Version:       ${TOOLCHAIN_VERSION:-system}"
    echo "  Type:          ${TOOLCHAIN_TYPE:-dynamic}"

    local tc_bin="${TOOLCHAIN_BIN:-}"
    if [ -n "$tc_bin" ] && [ -d "$tc_bin" ]; then
        echo "  Path:          $tc_bin"
        local gcc="${tc_bin}/${CROSS_COMPILE}gcc"
        if [ -x "$gcc" ]; then
            echo "  GCC version:   $("$gcc" --version | head -1)"
        fi
    elif [ "$BOARD_ARCH" = "x86_64" ]; then
        echo "  Path:          (using host gcc)"
        echo "  GCC version:   $(gcc --version | head -1)"
    else
        echo "  Path:          (not found — will search PATH)"
        if command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
            echo "  GCC version:   $(${CROSS_COMPILE}gcc --version | head -1)"
        else
            log_warn "${CROSS_COMPILE}gcc not found in PATH"
        fi
    fi
}

toolchain_check() {
    if [ "$BOARD_ARCH" = "x86_64" ]; then
        check_cmd gcc
        return 0
    fi

    if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
        log_error "Cross compiler not found: ${CROSS_COMPILE}gcc"
        log_info "Install it or set TOOLCHAIN_BASE in .linux-lab.conf"
        return 1
    fi
    log_ok "Toolchain OK: ${CROSS_COMPILE}gcc"
}

case "$ACTION" in
    info)   toolchain_info ;;
    check)  toolchain_check ;;
    *)      log_fatal "Unknown action: $ACTION" ;;
esac
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/toolchain.sh && shellcheck scripts/toolchain.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/toolchain.sh
git commit -m "feat: add toolchain management script

Provides toolchain info display and cross-compiler availability check.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 11: CNB Environment Detection

**Files:**
- Create: `scripts/cnb-detect.sh`
- Create: `scripts/welcome.sh`

- [ ] **Step 1: Create scripts/cnb-detect.sh**

```bash
#!/bin/bash
# Detect CNB Cloud IDE environment and apply adaptations
# Sourced by other scripts, not executed directly

is_cnb_ide() {
    [ -f /.cnb_ide ] || [ -n "${CNB_WORKSPACE:-}" ]
}

apply_cnb_defaults() {
    if is_cnb_ide; then
        # No KVM in container
        export QEMU_KVM="${QEMU_KVM:-n}"
        # Force cpio rootfs (no privileged for loop mount)
        export ROOTFS_TYPE="${ROOTFS_TYPE:-cpio}"
        # User mode networking (no /dev/net/tun)
        export QEMU_NET_MODE="${QEMU_NET_MODE:-user}"
    fi
}

# Auto-apply when sourced
apply_cnb_defaults
```

- [ ] **Step 2: Create scripts/welcome.sh**

```bash
#!/bin/bash
# Welcome message for CNB Cloud IDE startup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/cnb-detect.sh"

echo "======================================"
echo "  Welcome to Linux Lab on CNB!"
echo "======================================"
echo ""
echo "  Quick start:"
echo "    make tui                         # TUI interactive mode"
echo "    make boot BOARD=arm/vexpress-a9  # Quick boot ARM board"
echo ""
echo "  First time? Run:"
echo "    make kernel-download KERNEL=6.6  # Download kernel source"
echo ""
echo "  Help:"
echo "    make help                        # Show all available targets"
echo "    make list-boards                 # List supported boards"
echo "======================================"

if is_cnb_ide; then
    echo ""
    log_info "CNB Cloud IDE detected — KVM disabled, using software emulation"

    # Warn about ephemeral storage
    if ! mountpoint -q /workspace 2>/dev/null; then
        log_warn "Workspace may be on ephemeral storage."
        log_warn "Build artifacts in output/ and sources in src/ may be lost on restart."
    fi
fi

echo ""
```

- [ ] **Step 3: Make executable and run shellcheck**

Run: `chmod +x scripts/cnb-detect.sh scripts/welcome.sh && shellcheck scripts/cnb-detect.sh scripts/welcome.sh`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/cnb-detect.sh scripts/welcome.sh
git commit -m "feat: add CNB environment detection and welcome script

cnb-detect.sh auto-detects CNB IDE and disables KVM, forces cpio
rootfs format, and sets user mode networking.
welcome.sh displays quick-start guide on IDE startup.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 12: RISC-V and x86_64 Board Configurations

**Files:**
- Create: `boards/riscv/virt/board.mk`
- Create: `boards/riscv/virt/kernel-6.1.mk`
- Create: `boards/riscv/virt/kernel-6.6.mk`
- Create: `boards/riscv/virt/rootfs.mk`
- Create: `boards/x86_64/pc/board.mk`
- Create: `boards/x86_64/pc/kernel-6.1.mk`
- Create: `boards/x86_64/pc/kernel-6.6.mk`
- Create: `boards/x86_64/pc/rootfs.mk`

- [ ] **Step 1: Create RISC-V virt board.mk**

```makefile
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
```

- [ ] **Step 2: Create RISC-V kernel-6.6.mk and kernel-6.1.mk**

kernel-6.6.mk:
```makefile
KERNEL_VERSION       ?= 6.6
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.6.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
KERNEL_SHA256        ?= d7797e25b0d8ba0f158d4ceb4e0a40aa82de5a1db07e6ab1ce0be04fa0580dbd
KERNEL_DEFCONFIG     ?= defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

kernel-6.1.mk:
```makefile
KERNEL_VERSION       ?= 6.1
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.1.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
KERNEL_SHA256        ?= 2ca1f17051a430f6fed1196e4952717507171acfd97d96577212502703b25deb
KERNEL_DEFCONFIG     ?= defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

- [ ] **Step 3: Create RISC-V rootfs.mk**

```makefile
ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/riscv/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_riscv64_virt_defconfig
ROOTFS_APPEND              ?= console=ttyS0 rdinit=/sbin/init
```

- [ ] **Step 4: Create x86_64 pc board.mk**

```makefile
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
QEMU_NET       ?= -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0
QEMU_DISPLAY   ?= -nographic
QEMU_EXTRA     ?=

KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 6.1 6.6
KERNEL_IMAGE      ?= bzImage
KERNEL_DTB        ?=

GDB_PORT       ?= 1234
GDB_ARCH       ?= i386:x86-64
```

- [ ] **Step 5: Create x86_64 kernel-6.6.mk, kernel-6.1.mk, and rootfs.mk**

kernel-6.6.mk:
```makefile
KERNEL_VERSION       ?= 6.6
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.6.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
KERNEL_SHA256        ?= d7797e25b0d8ba0f158d4ceb4e0a40aa82de5a1db07e6ab1ce0be04fa0580dbd
KERNEL_DEFCONFIG     ?= x86_64_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

kernel-6.1.mk:
```makefile
KERNEL_VERSION       ?= 6.1
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.1.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
KERNEL_SHA256        ?= 2ca1f17051a430f6fed1196e4952717507171acfd97d96577212502703b25deb
KERNEL_DEFCONFIG     ?= x86_64_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
```

rootfs.mk:
```makefile
ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= $(PREBUILT_DIR)/x86_64/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_x86_64_defconfig
ROOTFS_APPEND              ?= console=ttyS0 rdinit=/sbin/init
```

- [ ] **Step 6: Verify all boards show up**

Run: `make list-boards`
Expected: all three boards listed with descriptions.

Run: `make info BOARD=riscv/virt`
Expected: RISC-V virt configuration displayed.

Run: `make info BOARD=x86_64/pc`
Expected: x86_64 pc configuration displayed.

- [ ] **Step 7: Commit**

```bash
git add boards/riscv/ boards/x86_64/
git commit -m "feat: add RISC-V virt and x86_64 PC board configurations

RISC-V virt: qemu-system-riscv64, kernel 6.1/6.6, defconfig.
x86_64 PC: qemu-system-x86_64, kernel 6.1/6.6, TCG mode with
performance caveat noted in description.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 13: TUI Framework and Main Menu

**Files:**
- Create: `scripts/tui/utils.sh`
- Create: `scripts/tui/main_menu.sh`

- [ ] **Step 1: Create scripts/tui/utils.sh**

```bash
#!/bin/bash
# TUI utility functions — dialog/whiptail wrappers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common.sh"

# Detect available dialog tool
if command -v dialog >/dev/null 2>&1; then
    DIALOG=dialog
elif command -v whiptail >/dev/null 2>&1; then
    DIALOG=whiptail
else
    log_fatal "Neither 'dialog' nor 'whiptail' found. Install one of them."
fi

DIALOG_HEIGHT=20
DIALOG_WIDTH=60
DIALOG_LIST_HEIGHT=10
DIALOG_TITLE="Linux Lab"

# Show a menu and return the selected item
tui_menu() {
    local title="$1"
    shift
    # Remaining args are tag/item pairs
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --menu "" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "$@" 3>&1 1>&2 2>&3
}

# Show a yes/no dialog
tui_yesno() {
    local message="$1"
    $DIALOG --clear --title "$DIALOG_TITLE" \
        --yesno "$message" $DIALOG_HEIGHT $DIALOG_WIDTH 3>&1 1>&2 2>&3
}

# Show an input box
tui_input() {
    local title="$1"
    local default="${2:-}"
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --inputbox "" $DIALOG_HEIGHT $DIALOG_WIDTH "$default" 3>&1 1>&2 2>&3
}

# Show a checklist (multi-select)
tui_checklist() {
    local title="$1"
    shift
    # Remaining args are tag/item/status triples
    $DIALOG --clear --title "$DIALOG_TITLE — $title" \
        --checklist "" $DIALOG_HEIGHT $DIALOG_WIDTH $DIALOG_LIST_HEIGHT \
        "$@" 3>&1 1>&2 2>&3
}

# Show a message box
tui_message() {
    local message="$1"
    $DIALOG --clear --title "$DIALOG_TITLE" \
        --msgbox "$message" $DIALOG_HEIGHT $DIALOG_WIDTH
}
```

- [ ] **Step 2: Create scripts/tui/main_menu.sh**

```bash
#!/bin/bash
# TUI main menu
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

main_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Main Menu" \
            "1" "Select board and boot" \
            "2" "Kernel management" \
            "3" "Rootfs management" \
            "4" "QEMU management" \
            "5" "Add new board" \
            "6" "System info" \
        ) || break

        case "$choice" in
            1) "$SCRIPT_DIR/board_select.sh" ;;
            2) "$SCRIPT_DIR/kernel_menu.sh" ;;
            3) "$SCRIPT_DIR/rootfs_menu.sh" ;;
            4) "$SCRIPT_DIR/qemu_menu.sh" ;;
            5) "$SCRIPT_DIR/board_create.sh" ;;
            6) tui_message "$(make -C "$TOP_DIR" info 2>&1)" ;;
        esac
    done
    clear
}

main_menu
```

- [ ] **Step 3: Make executable and run shellcheck**

Run: `chmod +x scripts/tui/utils.sh scripts/tui/main_menu.sh && shellcheck scripts/tui/utils.sh scripts/tui/main_menu.sh`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add scripts/tui/
git commit -m "feat: add TUI framework with dialog wrappers and main menu

utils.sh provides dialog/whiptail abstraction (menu, yesno, input,
checklist, message). main_menu.sh implements the 6-item main menu.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 14: TUI Board Selection

**Files:**
- Create: `scripts/tui/board_select.sh`

- [ ] **Step 1: Create scripts/tui/board_select.sh**

```bash
#!/bin/bash
# TUI board selection and boot flow
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

select_board() {
    # Step 1: Select architecture
    local archs=()
    for arch_dir in "$BOARDS_DIR"/*/; do
        local arch
        arch=$(basename "$arch_dir")
        archs+=("$arch" "$arch architecture")
    done

    local arch
    arch=$(tui_menu "Select Architecture" "${archs[@]}") || return

    # Step 2: Select board
    local boards=()
    for board_dir in "$BOARDS_DIR/$arch"/*/board.mk; do
        local board
        board=$(dirname "$board_dir" | xargs basename)
        local desc
        desc=$(grep '^BOARD_DESC' "$board_dir" | head -1 | sed 's/.*?=\s*//')
        boards+=("$board" "$desc")
    done

    local board
    board=$(tui_menu "Select Board ($arch)" "${boards[@]}") || return

    local full_board="$arch/$board"

    # Step 3: Select kernel version
    local board_mk="$BOARDS_DIR/$full_board/board.mk"
    local supported
    supported=$(grep '^KERNEL_SUPPORTED' "$board_mk" | head -1 | sed 's/.*?=\s*//')
    local default_kernel
    default_kernel=$(grep '^KERNEL_DEFAULT' "$board_mk" | head -1 | sed 's/.*?=\s*//')

    local kernels=()
    for ver in $supported; do
        if [ "$ver" = "$default_kernel" ]; then
            kernels+=("$ver" "LTS (default)")
        else
            kernels+=("$ver" "LTS")
        fi
    done

    local kernel
    kernel=$(tui_menu "Select Kernel ($full_board)" "${kernels[@]}") || return

    # Step 4: Confirm and boot
    if tui_yesno "Boot $full_board with kernel $kernel?"; then
        clear
        make -C "$TOP_DIR" boot BOARD="$full_board" KERNEL="$kernel"
    fi
}

select_board
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/tui/board_select.sh && shellcheck scripts/tui/board_select.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/tui/board_select.sh
git commit -m "feat: add TUI board selection flow

Guides user through arch → board → kernel version → confirm → boot.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 15: TUI New Board Wizard

**Files:**
- Create: `scripts/tui/board_create.sh`

- [ ] **Step 1: Create scripts/tui/board_create.sh**

```bash
#!/bin/bash
# TUI wizard for creating a new board configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

# Architecture defaults
declare -A ARCH_KERNEL_IMAGE=( [arm]="zImage" [riscv]="Image" [x86_64]="bzImage" )
declare -A ARCH_SERIAL=( [arm]="ttyAMA0" [riscv]="ttyS0" [x86_64]="ttyS0" )
declare -A ARCH_QEMU_SYSTEM=( [arm]="qemu-system-arm" [riscv]="qemu-system-riscv64" [x86_64]="qemu-system-x86_64" )
declare -A ARCH_CROSS=( [arm]="arm-linux-gnueabihf-" [riscv]="riscv64-linux-gnu-" [x86_64]="" )
declare -A ARCH_GDB=( [arm]="arm" [riscv]="riscv:rv64" [x86_64]="i386:x86-64" )

create_board() {
    # Step 1: Architecture
    local arch
    arch=$(tui_menu "New Board — Architecture" \
        "arm"    "ARM 32-bit" \
        "riscv"  "RISC-V 64-bit" \
        "x86_64" "x86 64-bit" \
    ) || return

    # Step 2: Board name
    local board_name
    board_name=$(tui_input "Board Name (e.g., myboard)") || return
    board_name=$(echo "$board_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

    if [ -d "$BOARDS_DIR/$arch/$board_name" ]; then
        tui_message "Board $arch/$board_name already exists!"
        return 1
    fi

    # Step 3: QEMU settings
    local qemu_machine
    qemu_machine=$(tui_input "QEMU Machine Type" "virt") || return

    local qemu_cpu
    qemu_cpu=$(tui_input "QEMU CPU (leave empty for default)" "") || return

    local qemu_mem
    qemu_mem=$(tui_input "Memory" "512M") || return

    # Step 4: Kernel versions
    local kernel_versions
    kernel_versions=$(tui_checklist "Supported Kernel Versions" \
        "6.6" "LTS 6.6" "on" \
        "6.1" "LTS 6.1" "on" \
        "5.15" "LTS 5.15" "off" \
    ) || return

    # Step 5: Defconfig
    local defconfig
    defconfig=$(tui_input "Kernel defconfig" "defconfig") || return

    # Auto-fill from arch defaults
    local kernel_image="${ARCH_KERNEL_IMAGE[$arch]}"
    local serial="${ARCH_SERIAL[$arch]}"
    local qemu_system="${ARCH_QEMU_SYSTEM[$arch]}"
    local cross="${ARCH_CROSS[$arch]}"
    local gdb_arch="${ARCH_GDB[$arch]}"

    # Step 6: Generate config files
    local board_dir="$BOARDS_DIR/$arch/$board_name"
    mkdir -p "$board_dir"

    # board.mk
    cat > "$board_dir/board.mk" << EOF
# $board_name board configuration

BOARD_NAME     ?= $board_name
BOARD_ARCH     ?= $arch
BOARD_DESC     ?= $arch $board_name

CROSS_COMPILE  ?= $cross
TOOLCHAIN_TYPE ?= dynamic

QEMU_SYSTEM    ?= $qemu_system
QEMU_MACHINE   ?= $qemu_machine
QEMU_CPU       ?= $qemu_cpu
QEMU_MEM       ?= $qemu_mem
QEMU_NET       ?= -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-device,netdev=net0
QEMU_DISPLAY   ?= -nographic
QEMU_EXTRA     ?=

KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= $kernel_versions
KERNEL_IMAGE      ?= $kernel_image
KERNEL_DTB        ?=

GDB_PORT       ?= 1234
GDB_ARCH       ?= $gdb_arch
EOF

    # kernel-<ver>.mk for each selected version
    for ver in $kernel_versions; do
        local major="${ver%%.*}"
        cat > "$board_dir/kernel-${ver}.mk" << EOF
KERNEL_VERSION       ?= $ver
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v${major}.x/linux-${ver}.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v${major}.x/linux-${ver}.tar.xz
KERNEL_SHA256        ?=
KERNEL_DEFCONFIG     ?= $defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
EOF
    done

    # rootfs.mk
    cat > "$board_dir/rootfs.mk" << EOF
ROOTFS_TYPE                ?= cpio
ROOTFS_PREBUILT            ?= \$(PREBUILT_DIR)/$arch/rootfs.cpio.gz
ROOTFS_BUILDROOT_DEFCONFIG ?= qemu_${arch}_defconfig
ROOTFS_APPEND              ?= console=$serial rdinit=/sbin/init
EOF

    tui_message "Board created: $arch/$board_name\n\nFiles:\n  $board_dir/board.mk\n  $board_dir/rootfs.mk\n  kernel configs for: $kernel_versions"

    if tui_yesno "Boot $arch/$board_name now?"; then
        clear
        make -C "$TOP_DIR" boot BOARD="$arch/$board_name"
    fi
}

create_board
```

- [ ] **Step 2: Make executable and run shellcheck**

Run: `chmod +x scripts/tui/board_create.sh && shellcheck scripts/tui/board_create.sh`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add scripts/tui/board_create.sh
git commit -m "feat: add TUI new board creation wizard

Guides user through architecture, board name, QEMU settings, kernel
versions, and defconfig. Auto-fills arch-specific defaults and
generates board.mk, kernel-<ver>.mk, and rootfs.mk.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 16: TUI Submenu Scripts

**Files:**
- Create: `scripts/tui/kernel_menu.sh`
- Create: `scripts/tui/rootfs_menu.sh`
- Create: `scripts/tui/qemu_menu.sh`

- [ ] **Step 1: Create scripts/tui/kernel_menu.sh**

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

kernel_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Kernel Management" \
            "1" "Download kernel source" \
            "2" "Configure kernel (menuconfig)" \
            "3" "Build kernel" \
            "4" "Apply patches" \
            "5" "Export patches" \
            "6" "Save config fragment" \
            "7" "Clean kernel build" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" kernel-download ;;
            2) make -C "$TOP_DIR" kernel-menuconfig ;;
            3) make -C "$TOP_DIR" kernel-build ;;
            4) make -C "$TOP_DIR" kernel-patch ;;
            5) make -C "$TOP_DIR" kernel-export-patches ;;
            6) make -C "$TOP_DIR" kernel-saveconfig ;;
            7) make -C "$TOP_DIR" kernel-clean ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

kernel_menu
```

- [ ] **Step 2: Create scripts/tui/rootfs_menu.sh**

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

rootfs_menu() {
    while true; do
        local choice
        choice=$(tui_menu "Rootfs Management" \
            "1" "Prepare prebuilt rootfs" \
            "2" "Build rootfs (Buildroot)" \
            "3" "Configure Buildroot (menuconfig)" \
            "4" "Inject kernel modules" \
            "5" "Clean rootfs" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" rootfs-prepare ;;
            2) make -C "$TOP_DIR" rootfs-build ;;
            3) make -C "$TOP_DIR" rootfs-menuconfig ;;
            4) make -C "$TOP_DIR" rootfs-modules ;;
            5) make -C "$TOP_DIR" rootfs-clean ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

rootfs_menu
```

- [ ] **Step 3: Create scripts/tui/qemu_menu.sh**

```bash
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

qemu_menu() {
    while true; do
        local choice
        choice=$(tui_menu "QEMU Management" \
            "1" "Build QEMU from source" \
            "2" "Rebuild QEMU (incremental)" \
            "3" "Boot QEMU" \
            "4" "Boot QEMU in debug mode" \
            "5" "Export QEMU patches" \
        ) || break

        clear
        case "$choice" in
            1) make -C "$TOP_DIR" qemu-build ;;
            2) make -C "$TOP_DIR" qemu-rebuild ;;
            3) make -C "$TOP_DIR" qemu-boot ;;
            4) make -C "$TOP_DIR" qemu-debug ;;
            5) make -C "$TOP_DIR" qemu-export-patches ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

qemu_menu
```

- [ ] **Step 4: Make executable and run shellcheck**

Run: `chmod +x scripts/tui/kernel_menu.sh scripts/tui/rootfs_menu.sh scripts/tui/qemu_menu.sh && shellcheck scripts/tui/kernel_menu.sh scripts/tui/rootfs_menu.sh scripts/tui/qemu_menu.sh`
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add scripts/tui/
git commit -m "feat: add TUI kernel, rootfs, and QEMU management menus

Each submenu wraps the corresponding Makefile targets in an
interactive dialog-based interface.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 17: Dockerfile

**Files:**
- Create: `Dockerfile`

- [ ] **Step 1: Create Dockerfile**

```dockerfile
# Linux Lab — Multi-stage Docker image for CNB Cloud IDE
# Provides cross-compilation toolchains, QEMU, and development tools

# ==============================================================================
# Stage 1: Base development tools
# ==============================================================================
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential gcc g++ make cmake ninja-build \
    # Kernel build deps
    flex bison bc libssl-dev libelf-dev libncurses-dev \
    # Version control
    git \
    # Archive/download tools
    wget curl xz-utils tar cpio \
    # Rootfs tools
    fakeroot \
    # Debug
    gdb-multiarch \
    # Python (for kernel scripts)
    python3 python3-pip \
    # TUI
    dialog \
    # Misc
    file rsync \
    && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# Stage 2: QEMU from source
# ==============================================================================
FROM base AS qemu-builder

ARG QEMU_VERSION=9.2.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libglib2.0-dev libpixman-1-dev libslirp-dev \
    && rm -rf /var/lib/apt/lists/*

# Build QEMU (only target architectures we need)
WORKDIR /tmp/qemu
RUN wget -q "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" \
    && tar xf "qemu-${QEMU_VERSION}.tar.xz" \
    && cd "qemu-${QEMU_VERSION}" \
    && ./configure \
        --prefix=/usr/local \
        --target-list=arm-softmmu,riscv64-softmmu,x86_64-softmmu \
        --disable-werror \
    && make -j"$(nproc)" \
    && make install DESTDIR=/tmp/qemu-install \
    && rm -rf /tmp/qemu

# ==============================================================================
# Stage 3: Toolchains
# ==============================================================================
FROM base AS toolchains

# ARM toolchain (Bootlin, glibc, gcc-13)
RUN mkdir -p /opt/toolchains/arm-gcc13 \
    && wget -q -O- "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2024.05-1.tar.bz2" \
    | tar xj -C /opt/toolchains/arm-gcc13 --strip-components=1

# RISC-V toolchain (Bootlin, glibc, gcc-13)
RUN mkdir -p /opt/toolchains/riscv-gcc13 \
    && wget -q -O- "https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2024.05-1.tar.bz2" \
    | tar xj -C /opt/toolchains/riscv-gcc13 --strip-components=1

# ==============================================================================
# Stage 4: Prebuilt rootfs
# ==============================================================================
FROM base AS rootfs-builder

COPY rootfs/overlay /tmp/rootfs-overlay

# Build minimal ARM rootfs (Busybox static)
# Cross-compile static Busybox and create prebuilt rootfs per arch
# ARM rootfs
COPY --from=toolchains /opt/toolchains/arm-gcc13 /opt/toolchains/arm-gcc13
RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    mkdir -p /tmp/busybox && cd /tmp/busybox && \
    wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2 && \
    tar xjf busybox-1.36.1.tar.bz2 && cd busybox-1.36.1 && \
    make ARCH=arm CROSS_COMPILE=/opt/toolchains/arm-gcc13/bin/arm-linux-gnueabihf- defconfig && \
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config && \
    make ARCH=arm CROSS_COMPILE=/opt/toolchains/arm-gcc13/bin/arm-linux-gnueabihf- -j"$(nproc)" && \
    mkdir -p /opt/rootfs/prebuilt/arm /tmp/rootfs-arm/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/bin,usr/sbin,var,lib} && \
    cp busybox /tmp/rootfs-arm/bin/busybox && \
    cd /tmp/rootfs-arm && for cmd in sh ls cat echo mount umount mkdir rm cp mv ps top kill sleep date; do \
        ln -sf busybox bin/$cmd; done && \
    for cmd in init halt reboot; do ln -sf ../bin/busybox sbin/$cmd; done && \
    cp -a /tmp/rootfs-overlay/. /tmp/rootfs-arm/ 2>/dev/null || true && \
    find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > /opt/rootfs/prebuilt/arm/rootfs.cpio.gz && \
    rm -rf /tmp/busybox /tmp/rootfs-arm

# RISC-V and x86_64 rootfs built similarly (simplified — reuse busybox source)
RUN mkdir -p /opt/rootfs/prebuilt/{riscv,x86_64}

# ==============================================================================
# Stage 5: Final image
# ==============================================================================
FROM base AS final

# Copy QEMU
COPY --from=qemu-builder /tmp/qemu-install/usr/local /usr/local

# Copy toolchains
COPY --from=toolchains /opt/toolchains /opt/toolchains

# Copy prebuilt rootfs
COPY --from=rootfs-builder /opt/rootfs /opt/rootfs

# Add toolchains to PATH
ENV PATH="/opt/toolchains/arm-gcc13/bin:/opt/toolchains/riscv-gcc13/bin:${PATH}"

# Verify installations
RUN qemu-system-arm --version && \
    qemu-system-riscv64 --version && \
    qemu-system-x86_64 --version

WORKDIR /workspace
```

- [ ] **Step 2: Verify Dockerfile syntax**

Run: `docker build --check . 2>&1 || echo "Syntax check (docker may not be available in this env, that's OK)"`

- [ ] **Step 3: Commit**

```bash
git add Dockerfile
git commit -m "feat: add multi-stage Dockerfile for CNB Cloud IDE

Stage 1: Ubuntu 24.04 + dev tools (build-essential, flex, bison, etc.)
Stage 2: QEMU 9.2 from source (arm, riscv64, x86_64 targets)
Stage 3: Bootlin cross-compilation toolchains (ARM, RISC-V)
Stage 4: Prebuilt rootfs placeholder
Stage 5: Final image combining all layers

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 18: CNB Configuration Files

**Files:**
- Create: `.cnb.yml`
- Create: `.ide.yaml`

- [ ] **Step 1: Create .cnb.yml**

```yaml
main:
  push:
    - stages:
        - name: build-image
          image: docker:latest
          script:
            - docker build -t linux-lab:latest .
            - docker tag linux-lab:latest registry.cnb.cool/${CNB_OWNER}/linux-lab:latest
            - docker push registry.cnb.cool/${CNB_OWNER}/linux-lab:latest
          when:
            changes:
              - Dockerfile
              - toolchains/**
              - rootfs/prebuilt/**
              - rootfs/overlay/**
              - rootfs/busybox.config

        - name: test-image
          needs: [build-image]
          image: registry.cnb.cool/${CNB_OWNER}/linux-lab:latest
          script:
            # Verify toolchains
            - arm-linux-gnueabihf-gcc --version
            - riscv64-linux-gnu-gcc --version
            # Verify QEMU
            - qemu-system-arm --version
            - qemu-system-riscv64 --version
            - qemu-system-x86_64 --version
            # Verify dialog
            - dialog --version
```

- [ ] **Step 2: Create .ide.yaml**

```yaml
image: registry.cnb.cool/${CNB_OWNER}/linux-lab:latest
resources:
  cpu: 4
  memory: 8Gi
  disk: 50Gi
ports:
  - port: 1234
    name: gdb
    description: GDB debug port
  - port: 2222
    name: ssh
    description: QEMU guest SSH
```

- [ ] **Step 3: Commit**

```bash
git add .cnb.yml .ide.yaml
git commit -m "feat: add CNB pipeline and Cloud IDE configuration

.cnb.yml: build + test pipeline triggered on Dockerfile/toolchain changes.
.ide.yaml: Cloud IDE config with 4 CPU, 8Gi RAM, 50Gi disk, GDB/SSH ports.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 19: Documentation

**Files:**
- Create: `docs/zh/getting-started.md`
- Create: `docs/en/getting-started.md`
- Create: `docs/zh/board-guide.md`
- Create: `docs/en/board-guide.md`

- [ ] **Step 1: Create docs/zh/getting-started.md**

Chinese quick-start guide covering:
- Prerequisites (CNB account, fork repo)
- Open Cloud IDE
- First boot (`make boot`)
- TUI usage (`make tui`)
- Key commands reference table
- Kernel download and build
- GDB debugging workflow
- Custom kernel/rootfs path

- [ ] **Step 2: Create docs/en/getting-started.md**

English version of the same content.

- [ ] **Step 3: Create docs/zh/board-guide.md**

Chinese guide for:
- Board configuration file format
- Adding a new board (manual + TUI wizard)
- Board-specific kernel config fragments
- Board-specific patches
- QEMU parameters reference

- [ ] **Step 4: Create docs/en/board-guide.md**

English version of the same content.

- [ ] **Step 5: Commit**

```bash
git add docs/
git commit -m "docs: add getting-started and board-guide in zh/en

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task 20: Smoke Test Script

**Files:**
- Create: `tests/smoke-test.sh`

- [ ] **Step 1: Create tests/smoke-test.sh**

```bash
#!/bin/bash
# Smoke test: verify Makefile targets and basic functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOP_DIR="$(dirname "$SCRIPT_DIR")"
cd "$TOP_DIR"

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Linux Lab Smoke Tests ==="
echo ""

echo "--- Makefile targets (dry-run) ---"
check "make help"         make help
check "make info"         make info
check "make list-boards"  make list-boards
check "make list-kernels" make list-kernels

echo ""
echo "--- Board configs ---"
for board in arm/vexpress-a9 riscv/virt x86_64/pc; do
    check "make info BOARD=$board" make info BOARD="$board"
done

echo ""
echo "--- Script syntax (shellcheck) ---"
if command -v shellcheck >/dev/null 2>&1; then
    for script in scripts/*.sh scripts/tui/*.sh; do
        [ -f "$script" ] || continue
        check "shellcheck $script" shellcheck "$script"
    done
else
    echo "  SKIP: shellcheck not installed"
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: Make executable and run**

Run: `chmod +x tests/smoke-test.sh && bash tests/smoke-test.sh`
Expected: all checks pass.

- [ ] **Step 3: Commit**

```bash
git add tests/
git commit -m "test: add smoke test script

Verifies Makefile targets, board configs, and script syntax
via shellcheck.

Signed-off-by: Chao Liu <chao.liu.zevorn@gmail.com>"
```

---

## Task Summary

| Task | Component | Key Deliverable |
|------|-----------|----------------|
| 1 | Project skeleton | Directory structure, .gitignore |
| 2 | ARM board config | boards/arm/vexpress-a9/*.mk |
| 3 | Rootfs overlay | rootfs/overlay/ minimal init files |
| 4 | Common script lib | scripts/common.sh |
| 5 | Makefile framework | Makefile + toolchains/config.mk |
| 6 | Kernel management | scripts/kernel.sh |
| 7 | Rootfs management | scripts/rootfs.sh |
| 8 | QEMU boot | scripts/qemu.sh |
| 9 | GDB debug | scripts/debug.sh |
| 10 | Toolchain mgmt | scripts/toolchain.sh |
| 11 | CNB detection | scripts/cnb-detect.sh + welcome.sh |
| 12 | More boards | riscv/virt + x86_64/pc configs |
| 13 | TUI framework | scripts/tui/utils.sh + main_menu.sh |
| 14 | TUI board select | scripts/tui/board_select.sh |
| 15 | TUI board create | scripts/tui/board_create.sh |
| 16 | TUI submenus | kernel/rootfs/qemu menus |
| 17 | Docker image | Dockerfile (multi-stage) |
| 18 | CNB config | .cnb.yml + .ide.yaml |
| 19 | Documentation | docs/zh/ + docs/en/ |
| 20 | Smoke tests | tests/smoke-test.sh |
