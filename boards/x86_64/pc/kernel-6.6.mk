KERNEL_VERSION       ?= 6.6
KERNEL_URL           ?= https://mirrors.tuna.tsinghua.edu.cn/kernel/v6.x/linux-6.6.tar.xz
KERNEL_URL_ALT       ?= https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.tar.xz
KERNEL_SHA256        ?= d926a06c63dd8ac7df3f86ee1ffc2ce2a3b81a2d168484e76b5b389aba8e56d0
KERNEL_DEFCONFIG     ?= x86_64_defconfig
KERNEL_CONFIG_EXTRA  ?=
TOOLCHAIN_VERSION    ?= gcc-13
