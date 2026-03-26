# Linux Lab — Docker image for CNB Cloud IDE
# Provides cross-compilation toolchains, QEMU, and development tools

# ==============================================================================
# Stage 1: Base development tools + cross-compilers
# ==============================================================================
FROM ubuntu:24.04 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential gcc g++ make cmake ninja-build \
    # Kernel build deps
    flex bison bc libssl-dev libelf-dev libncurses-dev \
    # Cross-compilers (from Ubuntu apt — fast, no external download)
    gcc-arm-linux-gnueabihf \
    gcc-riscv64-linux-gnu \
    # Version control
    git \
    # Archive/download tools
    wget curl xz-utils tar cpio \
    # QEMU runtime deps
    libglib2.0-0 libpixman-1-0 libslirp0 \
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

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config libglib2.0-dev libpixman-1-dev libslirp-dev \
    && rm -rf /var/lib/apt/lists/*

ARG QEMU_VERSION=10.2.2
WORKDIR /tmp
RUN wget --progress=dot:mega "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" \
    && tar xJf qemu-${QEMU_VERSION}.tar.xz \
    && mkdir -p /tmp/qemu-build && cd /tmp/qemu-build \
    && /tmp/qemu-${QEMU_VERSION}/configure \
        --prefix=/usr/local \
        --target-list=arm-softmmu,riscv64-softmmu,x86_64-softmmu \
        --disable-werror \
    && make -j"$(nproc)" \
    && make install DESTDIR=/tmp/qemu-install \
    && rm -rf /tmp/qemu-${QEMU_VERSION} /tmp/qemu-build /tmp/qemu-${QEMU_VERSION}.tar.xz

# ==============================================================================
# Stage 3: Prebuilt rootfs (repo-committed images)
# ==============================================================================
FROM base AS rootfs-builder

COPY rootfs/prebuilt /opt/rootfs/prebuilt

# ==============================================================================
# Stage 4: Final image
# ==============================================================================
FROM base AS final

# Copy QEMU from builder
COPY --from=qemu-builder /tmp/qemu-install/usr/local /usr/local

# Copy prebuilt rootfs
COPY --from=rootfs-builder /opt/rootfs /opt/rootfs

# Verify installations
RUN qemu-system-arm --version && \
    qemu-system-riscv64 --version && \
    qemu-system-x86_64 --version && \
    arm-linux-gnueabihf-gcc --version && \
    riscv64-linux-gnu-gcc --version

# Setup script: copy prebuilt rootfs into workspace on first IDE open
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
