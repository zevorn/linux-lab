# Linux Lab — Docker + QEMU based Linux development platform
# https://github.com/user/linux-lab

.PHONY: help boot tui info list-boards list-kernels clean distclean disk-usage
.PHONY: kernel-download kernel-patch kernel-config kernel-menuconfig
.PHONY: kernel-build kernel-rebuild kernel-clean kernel-saveconfig kernel-export-patches
.PHONY: rootfs-prepare rootfs-build rootfs-rebuild rootfs-menuconfig rootfs-modules rootfs-clean
.PHONY: qemu-build qemu-rebuild qemu-boot qemu-debug qemu-export-patches
.PHONY: debug boot-test check-submodules toolchain-check

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

# Validate kernel version is supported by board
ifneq ($(MAKECMDGOALS),help)
ifneq ($(MAKECMDGOALS),list-boards)
ifneq ($(MAKECMDGOALS),)
ifdef KERNEL_SUPPORTED
ifeq ($(filter $(KERNEL),$(KERNEL_SUPPORTED)),)
$(error Unsupported kernel version '$(KERNEL)' for board '$(BOARD)'. Supported: $(KERNEL_SUPPORTED))
endif
endif
endif
endif
endif

# Board-specific output directory
BOARD_OUTPUT := $(OUTPUT_DIR)/$(BOARD)
KERNEL_OUT   := $(BOARD_OUTPUT)/linux-$(KERNEL)

# QEMU binary: prefer user-built, then system PATH
QEMU_BIN ?= $(if $(wildcard $(OUTPUT_DIR)/qemu/bin/$(QEMU_SYSTEM)),$(OUTPUT_DIR)/qemu/bin/$(QEMU_SYSTEM),$(shell command -v $(QEMU_SYSTEM) 2>/dev/null))

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
QEMU_VERSION ?= 11.0.0
export QEMU_VERSION

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
	@echo "To deinitialize submodules: git submodule deinit -f src/qemu src/buildroot"
	@echo "Done."

# ==============================================================================
# Source management (QEMU and Buildroot cloned on demand)
# ==============================================================================
QEMU_REPO     ?= https://gitlab.com/qemu-project/qemu.git
QEMU_TAG      ?= v11.0.0
BUILDROOT_REPO ?= https://github.com/buildroot/buildroot.git
BUILDROOT_TAG  ?= 2024.02

check-submodules:
	@if [ ! -f "$(QEMU_SRC)/configure" ]; then \
		echo "Cloning QEMU $(QEMU_TAG)..."; \
		git clone --branch $(QEMU_TAG) --depth=1 $(QEMU_REPO) $(QEMU_SRC); \
	fi
	@if [ ! -f "$(BUILDROOT_SRC)/Makefile" ]; then \
		echo "Cloning Buildroot $(BUILDROOT_TAG)..."; \
		git clone --branch $(BUILDROOT_TAG) --depth=1 $(BUILDROOT_REPO) $(BUILDROOT_SRC); \
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
# Toolchain targets
# ==============================================================================
toolchain-check:
	@$(SCRIPTS_DIR)/toolchain.sh check

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
