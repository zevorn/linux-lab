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
RUN wget --no-check-certificate "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" \
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

# ARM toolchain (Bootlin, glibc)
RUN mkdir -p /opt/toolchains/arm-gcc13 \
    && wget -q -O- "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2024.05-1.tar.xz" \
    | tar xJ -C /opt/toolchains/arm-gcc13 --strip-components=1

# RISC-V toolchain (Bootlin, glibc, gcc-13)
# Bootlin prefix is riscv64-buildroot-linux-gnu-; create symlinks for riscv64-linux-gnu-
RUN mkdir -p /opt/toolchains/riscv-gcc13 \
    && wget -q -O- "https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2024.05-1.tar.xz" \
    | tar xJ -C /opt/toolchains/riscv-gcc13 --strip-components=1 \
    && cd /opt/toolchains/riscv-gcc13/bin \
    && for f in riscv64-buildroot-linux-gnu-*; do \
        ln -sf "$f" "$(echo "$f" | sed 's/riscv64-buildroot-linux-gnu-/riscv64-linux-gnu-/')"; \
    done

# ==============================================================================
# Stage 4: Prebuilt rootfs
# ==============================================================================
FROM base AS rootfs-builder

COPY rootfs/overlay /tmp/rootfs-overlay
COPY rootfs/busybox.config /tmp/busybox.config

# Cross-compile static Busybox and create prebuilt rootfs per arch
# ARM rootfs
COPY --from=toolchains /opt/toolchains/arm-gcc13 /opt/toolchains/arm-gcc13
RUN apt-get update && apt-get install -y --no-install-recommends wget && \
    mkdir -p /tmp/busybox && cd /tmp/busybox && \
    wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2 && \
    tar xjf busybox-1.36.1.tar.bz2 && cd busybox-1.36.1 && \
    make ARCH=arm CROSS_COMPILE=/opt/toolchains/arm-gcc13/bin/arm-linux-gnueabihf- defconfig && \
    cat /tmp/busybox.config >> .config && \
    make ARCH=arm CROSS_COMPILE=/opt/toolchains/arm-gcc13/bin/arm-linux-gnueabihf- olddefconfig && \
    make ARCH=arm CROSS_COMPILE=/opt/toolchains/arm-gcc13/bin/arm-linux-gnueabihf- -j"$(nproc)" && \
    mkdir -p /opt/rootfs/prebuilt/arm /tmp/rootfs-arm/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/bin,usr/sbin,var,lib} && \
    cp busybox /tmp/rootfs-arm/bin/busybox && \
    cd /tmp/rootfs-arm && for cmd in sh ls cat echo mount umount mkdir rm cp mv ps top kill sleep date; do \
        ln -sf busybox bin/$cmd; done && \
    for cmd in init halt reboot; do ln -sf ../bin/busybox sbin/$cmd; done && \
    cp -a /tmp/rootfs-overlay/. /tmp/rootfs-arm/ 2>/dev/null || true && \
    find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > /opt/rootfs/prebuilt/arm/rootfs.cpio.gz && \
    rm -rf /tmp/busybox /tmp/rootfs-arm

# RISC-V rootfs
COPY --from=toolchains /opt/toolchains/riscv-gcc13 /opt/toolchains/riscv-gcc13
RUN mkdir -p /tmp/busybox && cd /tmp/busybox && \
    wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2 && \
    tar xjf busybox-1.36.1.tar.bz2 && cd busybox-1.36.1 && \
    make ARCH=riscv CROSS_COMPILE=/opt/toolchains/riscv-gcc13/bin/riscv64-linux-gnu- defconfig && \
    cat /tmp/busybox.config >> .config && \
    make ARCH=riscv CROSS_COMPILE=/opt/toolchains/riscv-gcc13/bin/riscv64-linux-gnu- olddefconfig && \
    make ARCH=riscv CROSS_COMPILE=/opt/toolchains/riscv-gcc13/bin/riscv64-linux-gnu- -j"$(nproc)" && \
    mkdir -p /opt/rootfs/prebuilt/riscv /tmp/rootfs-riscv/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/bin,usr/sbin,var,lib} && \
    cp busybox /tmp/rootfs-riscv/bin/busybox && \
    cd /tmp/rootfs-riscv && for cmd in sh ls cat echo mount umount mkdir rm cp mv ps top kill sleep date; do \
        ln -sf busybox bin/$cmd; done && \
    for cmd in init halt reboot; do ln -sf ../bin/busybox sbin/$cmd; done && \
    cp -a /tmp/rootfs-overlay/. /tmp/rootfs-riscv/ 2>/dev/null || true && \
    find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > /opt/rootfs/prebuilt/riscv/rootfs.cpio.gz && \
    rm -rf /tmp/busybox /tmp/rootfs-riscv

# x86_64 rootfs (uses host gcc, no cross-compiler needed)
RUN mkdir -p /tmp/busybox && cd /tmp/busybox && \
    wget -q https://busybox.net/downloads/busybox-1.36.1.tar.bz2 && \
    tar xjf busybox-1.36.1.tar.bz2 && cd busybox-1.36.1 && \
    make defconfig && \
    cat /tmp/busybox.config >> .config && \
    make olddefconfig && \
    make -j"$(nproc)" && \
    mkdir -p /opt/rootfs/prebuilt/x86_64 /tmp/rootfs-x86/{bin,sbin,etc/init.d,dev,proc,sys,tmp,root,usr/bin,usr/sbin,var,lib} && \
    cp busybox /tmp/rootfs-x86/bin/busybox && \
    cd /tmp/rootfs-x86 && for cmd in sh ls cat echo mount umount mkdir rm cp mv ps top kill sleep date; do \
        ln -sf busybox bin/$cmd; done && \
    for cmd in init halt reboot; do ln -sf ../bin/busybox sbin/$cmd; done && \
    cp -a /tmp/rootfs-overlay/. /tmp/rootfs-x86/ 2>/dev/null || true && \
    find . | fakeroot cpio -o -H newc 2>/dev/null | gzip > /opt/rootfs/prebuilt/x86_64/rootfs.cpio.gz && \
    rm -rf /tmp/busybox /tmp/rootfs-x86

# ==============================================================================
# Stage 5: Final image
# ==============================================================================
FROM base AS final

# Copy QEMU
COPY --from=qemu-builder /tmp/qemu-install/usr/local /usr/local

# Copy toolchains
COPY --from=toolchains /opt/toolchains /opt/toolchains

# Copy prebuilt rootfs to both /opt (system) and workspace (runtime)
COPY --from=rootfs-builder /opt/rootfs /opt/rootfs

# Add toolchains to PATH
ENV PATH="/opt/toolchains/arm-gcc13/bin:/opt/toolchains/riscv-gcc13/bin:${PATH}"

# Verify installations
RUN qemu-system-arm --version && \
    qemu-system-riscv64 --version && \
    qemu-system-x86_64 --version

# On startup, link prebuilt rootfs into the workspace if not already present
RUN echo '#!/bin/sh' > /usr/local/bin/setup-rootfs.sh && \
    echo 'for arch in arm riscv x86_64; do' >> /usr/local/bin/setup-rootfs.sh && \
    echo '  src="/opt/rootfs/prebuilt/$arch/rootfs.cpio.gz"' >> /usr/local/bin/setup-rootfs.sh && \
    echo '  dst="/workspace/rootfs/prebuilt/$arch/rootfs.cpio.gz"' >> /usr/local/bin/setup-rootfs.sh && \
    echo '  if [ -f "$src" ] && [ ! -f "$dst" ]; then' >> /usr/local/bin/setup-rootfs.sh && \
    echo '    mkdir -p "$(dirname "$dst")"' >> /usr/local/bin/setup-rootfs.sh && \
    echo '    cp "$src" "$dst"' >> /usr/local/bin/setup-rootfs.sh && \
    echo '  fi' >> /usr/local/bin/setup-rootfs.sh && \
    echo 'done' >> /usr/local/bin/setup-rootfs.sh && \
    chmod +x /usr/local/bin/setup-rootfs.sh

WORKDIR /workspace
