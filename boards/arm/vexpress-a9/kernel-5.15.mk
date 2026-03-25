# Kernel 5.15 configuration for ARM vexpress-a9

KERNEL_VERSION       ?= 5.15
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v5.x/linux-5.15.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.tar.xz
KERNEL_SHA256        ?=
KERNEL_DEFCONFIG     ?= vexpress_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
