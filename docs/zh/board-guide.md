# 开发板配置指南

## 配置文件结构

每个开发板由三类配置文件定义：

```
boards/<arch>/<board>/
├── board.mk            # 板级通用配置
├── kernel-<ver>.mk     # 内核版本特定配置
└── rootfs.mk           # 根文件系统配置
```

## board.mk 格式

```makefile
BOARD_NAME     ?= <board-name>
BOARD_ARCH     ?= <arm|riscv|x86_64>
BOARD_DESC     ?= <description>
CROSS_COMPILE  ?= <cross-compiler-prefix>
QEMU_SYSTEM    ?= <qemu-system-xxx>
QEMU_MACHINE   ?= <machine-type>
QEMU_MEM       ?= 512M
KERNEL_DEFAULT    ?= 6.6
KERNEL_SUPPORTED  ?= 6.1 6.6
KERNEL_IMAGE      ?= <zImage|Image|bzImage>
GDB_PORT       ?= 1234
```

## 手动添加开发板

1. 创建目录：`mkdir -p boards/<arch>/<board>`
2. 编写 `board.mk`、`kernel-<ver>.mk`、`rootfs.mk`
3. 验证：`make info BOARD=<arch>/<board>`

## 通过 TUI 添加开发板

```bash
make tui  # 选择 "5. Add new board"
```

## 补丁应用顺序

```
patches/linux/common/     → 所有版本通用
patches/linux/<version>/  → 特定版本
patches/linux/<board>/    → 特定开发板
```

## QEMU 参数参考

| 架构 | QEMU System | Machine | 内核镜像 | 串口 |
|------|-------------|---------|----------|------|
| ARM | qemu-system-arm | vexpress-a9 | zImage | ttyAMA0 |
| RISC-V | qemu-system-riscv64 | virt | Image | ttyS0 |
| x86_64 | qemu-system-x86_64 | pc | bzImage | ttyS0 |
