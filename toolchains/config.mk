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
