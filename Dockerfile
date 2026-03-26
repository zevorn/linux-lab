# Linux Lab — Docker image for CNB Cloud IDE
# Based on CNB default dev environment (includes code-server, git, etc.)

# ==============================================================================
# Stage 1: QEMU from source (build in separate stage to cache)
# ==============================================================================
FROM cnbcool/default-dev-env:latest AS qemu-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential pkg-config python3 python3-pip ninja-build \
    libglib2.0-dev libpixman-1-dev libslirp-dev \
    wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

ARG QEMU_VERSION=10.2.2
WORKDIR /tmp
RUN curl -fSL --retry 3 --progress-bar "https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz" -o qemu-${QEMU_VERSION}.tar.xz \
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
# Stage 2: Final image
# ==============================================================================
FROM cnbcool/default-dev-env:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install linux-lab specific tools + cross-compilers
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential gcc g++ make cmake ninja-build \
    # Kernel build deps
    flex bison bc libssl-dev libelf-dev libncurses-dev \
    # Cross-compilers (from Ubuntu apt — fast)
    gcc-arm-linux-gnueabihf \
    gcc-riscv64-linux-gnu \
    # QEMU runtime deps
    libglib2.0-0 libpixman-1-0 libslirp0 \
    # Rootfs tools
    fakeroot cpio \
    # Debug
    gdb-multiarch \
    # TUI
    dialog \
    # Misc
    file rsync \
    && rm -rf /var/lib/apt/lists/*

# Copy QEMU from builder stage
COPY --from=qemu-builder /tmp/qemu-install/usr/local /usr/local

# Copy prebuilt rootfs images
COPY rootfs/prebuilt /opt/rootfs/prebuilt

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
