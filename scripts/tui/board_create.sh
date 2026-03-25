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
declare -A ARCH_BR_DEFCONFIG=( [arm]="qemu_arm_vexpress_defconfig" [riscv]="qemu_riscv64_virt_defconfig" [x86_64]="qemu_x86_64_defconfig" )

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
    local kernel_versions_raw
    kernel_versions_raw=$(tui_checklist "Supported Kernel Versions" \
        "6.6" "LTS 6.6" "on" \
        "6.1" "LTS 6.1" "on" \
        "5.15" "LTS 5.15" "off" \
    ) || return
    # Normalize dialog output: strip quotes and normalize whitespace
    local kernel_versions
    kernel_versions=$(echo "$kernel_versions_raw" | tr -d '"' | tr -s ' ')

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
ROOTFS_BUILDROOT_DEFCONFIG ?= ${ARCH_BR_DEFCONFIG[$arch]}
ROOTFS_APPEND              ?= console=$serial rdinit=/sbin/init
EOF

    tui_message "Board created: $arch/$board_name\n\nFiles:\n  $board_dir/board.mk\n  $board_dir/rootfs.mk\n  kernel configs for: $kernel_versions"

    if tui_yesno "Boot $arch/$board_name now?"; then
        clear
        make -C "$TOP_DIR" boot BOARD="$arch/$board_name"
    fi
}

create_board
