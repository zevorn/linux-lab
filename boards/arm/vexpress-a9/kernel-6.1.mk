# Kernel 6.1 configuration for ARM vexpress-a9

KERNEL_VERSION       ?= 6.1
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.1.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.1.tar.xz
KERNEL_SHA256        ?= 2ca1f17051a430f6fed1196e4952717507171acfd97d96577212502703b25deb
KERNEL_DEFCONFIG     ?= vexpress_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
