# Linux Lab 快速上手指南

## 前置条件

- 一个 CNB (Cloud Native Build) 账号
- Fork 本仓库到你的 CNB 账号下
- 浏览器（推荐 Chrome / Firefox）

如果你在本地使用，还需要：

- Docker 安装并运行
- 至少 10GB 可用磁盘空间
- Git

## 打开 Cloud IDE

1. 在 CNB 上 fork `linux-lab` 仓库
2. 点击仓库页面的 **Cloud IDE** 按钮
3. 等待环境初始化完成（首次约 1-2 分钟）
4. 终端自动显示欢迎信息和环境状态

## 第一次启动

打开终端，执行一键启动命令：

```bash
make boot
```

该命令会自动完成以下步骤：

1. 检查内核源码，不存在则自动下载
2. 检查内核镜像，不存在则自动编译
3. 检查 rootfs，不存在则自动准备
4. 检查 QEMU，使用 Docker 预装版本
5. 启动 QEMU 虚拟机

默认启动 ARM vexpress-a9 开发板 + Linux 6.6 内核。

启动后你将看到 Linux 登录提示符，直接按回车即可登录（root 用户，无密码）。

退出 QEMU：按 `Ctrl-A` 然后按 `X`。

## TUI 交互界面

Linux Lab 提供基于 dialog 的 TUI 交互界面：

```bash
make tui
```

TUI 主菜单包括：

| 选项 | 说明 |
|------|------|
| 1. Select board and boot | 选择开发板并启动 |
| 2. Kernel management | 内核管理（下载、编译、配置） |
| 3. Rootfs management | 根文件系统管理 |
| 4. QEMU management | QEMU 管理 |
| 5. Add new board | 添加新开发板（向导） |
| 6. System info | 系统信息 |

使用方向键选择，回车确认，ESC 返回上级菜单。

## 常用命令参考

### 一键操作

| 命令 | 说明 |
|------|------|
| `make boot` | 全流程：编译内核 + 准备 rootfs + 启动 QEMU |
| `make tui` | 打开 TUI 交互界面 |
| `make boot BOARD=riscv/virt` | 启动 RISC-V 开发板 |
| `make boot BOARD=x86_64/pc` | 启动 x86_64 开发板 |

### 内核管理

| 命令 | 说明 |
|------|------|
| `make kernel-download` | 下载内核源码到 src/ |
| `make kernel-download KERNEL=5.15` | 下载指定版本内核 |
| `make kernel-config` | 生成 .config |
| `make kernel-menuconfig` | 交互式内核配置 |
| `make kernel-build` | 编译内核 |
| `make kernel-rebuild` | 增量编译内核 |
| `make kernel-clean` | 清除内核编译产物 |
| `make kernel-saveconfig` | 导出 config diff 为 fragment |

### 根文件系统

| 命令 | 说明 |
|------|------|
| `make rootfs-prepare` | 准备预编译 rootfs + overlay |
| `make rootfs-build` | Buildroot 完整编译 |
| `make rootfs-modules` | 注入内核模块到 rootfs |
| `make rootfs-menuconfig` | Buildroot 交互式配置 |

### QEMU

| 命令 | 说明 |
|------|------|
| `make qemu-boot` | 仅启动 QEMU（跳过内核编译） |
| `make qemu-debug` | 以 GDB 调试模式启动 QEMU |
| `make qemu-build` | 从源码编译 QEMU（自动 clone 源码） |
| `make check-submodules` | 按需 clone QEMU 和 Buildroot 源码 |

### 环境

| 命令 | 说明 |
|------|------|
| `make info` | 显示当前配置 |
| `make list-boards` | 列出可用开发板 |
| `make list-kernels` | 列出当前开发板支持的内核版本 |
| `make help` | 显示所有 make 目标 |
| `make clean` | 清除当前开发板的编译产物 |
| `make distclean` | 清除所有内容（包括下载的源码） |
| `make disk-usage` | 显示磁盘使用情况 |

## 内核下载与编译

### 下载内核源码

```bash
# 下载默认版本（由 board.mk 中 KERNEL_DEFAULT 决定）
make kernel-download

# 下载指定版本
make kernel-download KERNEL=6.1

# 使用 git clone（当需要完整历史时）
make kernel-download KERNEL=6.6 KERNEL_GIT=1
```

内核源码下载到 `src/linux-<version>/` 目录。默认使用清华镜像源，速度更快。

### 编译内核

```bash
# 编译（自动使用 -j$(nproc) 并行编译）
make kernel-build

# 先修改配置再编译
make kernel-menuconfig
make kernel-build

# 为其他开发板编译
make kernel-build BOARD=riscv/virt KERNEL=6.6
```

编译产物输出到 `output/<board>/linux-<version>/` 目录（out-of-tree 编译，同一源码可被多个开发板共享）。

### 使用自定义内核源码

```bash
make kernel-build BOARD=arm/vexpress-a9 KERNEL_SRC=/path/to/my-linux
```

## GDB 调试

GDB 调试需要两个终端：

**终端 1** — 以调试模式启动 QEMU：

```bash
make qemu-debug
```

QEMU 会以 `-s -S` 参数启动，等待 GDB 连接（默认端口 1234）。

**终端 2** — 启动 GDB 并连接：

```bash
make debug
```

该命令会自动：
1. 启动 `gdb-multiarch`
2. 加载当前内核的 `vmlinux` 符号文件
3. 连接到 QEMU GDB server (`target remote :1234`)

### 常用 GDB 命令

```
(gdb) break start_kernel        # 在 start_kernel 设置断点
(gdb) continue                   # 继续执行
(gdb) bt                         # 查看调用栈
(gdb) list                       # 查看源码
(gdb) print task_struct          # 打印变量
(gdb) info registers             # 查看寄存器
```

## 切换开发板

```bash
# 使用命令行参数
make boot BOARD=riscv/virt
make boot BOARD=x86_64/pc

# 持久化配置（写入 .linux-lab.conf）
echo "BOARD := riscv/virt" > .linux-lab.conf
make boot
```

配置优先级：命令行参数 > 环境变量 > `.linux-lab.conf` > 开发板默认值。

## 自定义 rootfs

```bash
# 使用自定义 rootfs 目录（目录内应包含 rootfs.cpio.gz）
make boot BOARD=arm/vexpress-a9 ROOTFS_SRC=/path/to/my-rootfs/

# 直接指定 rootfs 镜像文件
make boot BOARD=arm/vexpress-a9 ROOTFS_IMAGE=/path/to/my-rootfs.cpio.gz
```

## 故障排除

### QEMU 启动慢

CNB Cloud IDE 没有 KVM 支持，QEMU 使用纯软件模拟（TCG 模式）。x86_64-on-x86_64 约慢 10-50 倍，内核启动预计需要 2-5 分钟。这对于教学和调试场景足够使用。

### 磁盘空间不足

```bash
make disk-usage        # 查看磁盘使用情况
make clean             # 清除当前开发板编译产物
make distclean         # 清除所有内容
```

### 下载失败

内核下载默认使用清华镜像源，如果失败会自动回退到 cdn.kernel.org。你也可以手动配置镜像：

```bash
echo 'KERNEL_MIRROR := https://mirrors.aliyun.com/kernel' >> .linux-lab.conf
```
