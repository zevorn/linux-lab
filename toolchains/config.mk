# Toolchain path configuration
#
# Cross-compilers are installed via apt (gcc-arm-linux-gnueabihf,
# gcc-riscv64-linux-gnu) and are already in the system PATH.
# No custom TOOLCHAIN_BASE is needed for the default setup.
#
# For custom toolchains (e.g., Bootlin), set TOOLCHAIN_BASE and
# the paths below will prepend to PATH.

TOOLCHAIN_BASE ?=

# ARM toolchain paths (override for custom installs)
TOOLCHAIN_PATH_arm_gcc-13  ?= $(if $(TOOLCHAIN_BASE),$(TOOLCHAIN_BASE)/arm-gcc13/bin,)

# RISC-V toolchain paths
TOOLCHAIN_PATH_riscv_gcc-13 ?= $(if $(TOOLCHAIN_BASE),$(TOOLCHAIN_BASE)/riscv-gcc13/bin,)

# x86_64 uses host gcc
TOOLCHAIN_PATH_x86_64_gcc-13 ?=

# Resolve toolchain bin path for current board
TOOLCHAIN_BIN = $(TOOLCHAIN_PATH_$(BOARD_ARCH)_$(TOOLCHAIN_VERSION))

# Prepend toolchain to PATH if set
ifneq ($(TOOLCHAIN_BIN),)
    export PATH := $(TOOLCHAIN_BIN):$(PATH)
endif
