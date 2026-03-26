# Linux Lab — Docker image for CNB Cloud IDE
# Based on CNB default dev environment (includes code-server, git, etc.)

FROM cnbcool/default-dev-env:latest

ENV DEBIAN_FRONTEND=noninteractive

# Install all tools in one layer for fast build
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential gcc g++ make cmake ninja-build \
    # Kernel build deps
    flex bison bc libssl-dev libelf-dev libncurses-dev \
    # Cross-compilers (from Ubuntu apt — fast)
    gcc-arm-linux-gnueabihf \
    gcc-riscv64-linux-gnu \
    # QEMU system emulators (from Ubuntu apt — no source build needed)
    qemu-system-arm \
    qemu-system-misc \
    qemu-system-x86 \
    # Rootfs tools
    fakeroot cpio \
    # Debug
    gdb-multiarch \
    # TUI
    dialog \
    # Misc
    file rsync \
    && rm -rf /var/lib/apt/lists/*

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
