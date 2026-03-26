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

# Download and build QEMU release tarball (self-contained, no submodules needed)
ARG QEMU_VERSION=11.0.0
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
# Stage 3: Toolchains
# ==============================================================================
FROM base AS toolchains

# ARM toolchain (Bootlin, glibc)
# Download to file first (pipe from wget can break on slow networks)
# Bootlin prefix is arm-buildroot-linux-gnueabihf-; create symlinks for arm-linux-gnueabihf-
RUN mkdir -p /opt/toolchains/arm-gcc13 \
    && wget --progress=dot:mega "https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2024.05-1.tar.xz" \
       -O /tmp/arm-tc.tar.xz \
    && tar xJf /tmp/arm-tc.tar.xz -C /opt/toolchains/arm-gcc13 --strip-components=1 \
    && rm -f /tmp/arm-tc.tar.xz \
    && cd /opt/toolchains/arm-gcc13/bin \
    && for f in arm-buildroot-linux-gnueabihf-*; do \
        ln -sf "$f" "$(echo "$f" | sed 's/arm-buildroot-linux-gnueabihf-/arm-linux-gnueabihf-/')"; \
    done

# RISC-V toolchain (Bootlin, glibc, gcc-13)
# Bootlin prefix is riscv64-buildroot-linux-gnu-; create symlinks for riscv64-linux-gnu-
RUN mkdir -p /opt/toolchains/riscv-gcc13 \
    && wget --progress=dot:mega "https://toolchains.bootlin.com/downloads/releases/toolchains/riscv64-lp64d/tarballs/riscv64-lp64d--glibc--stable-2024.05-1.tar.xz" \
       -O /tmp/riscv-tc.tar.xz \
    && tar xJf /tmp/riscv-tc.tar.xz -C /opt/toolchains/riscv-gcc13 --strip-components=1 \
    && rm -f /tmp/riscv-tc.tar.xz \
    && cd /opt/toolchains/riscv-gcc13/bin \
    && for f in riscv64-buildroot-linux-gnu-*; do \
        ln -sf "$f" "$(echo "$f" | sed 's/riscv64-buildroot-linux-gnu-/riscv64-linux-gnu-/')"; \
    done

# ==============================================================================
# Stage 4: Prebuilt rootfs (use repo-committed images)
# ==============================================================================
FROM base AS rootfs-builder

# Use the prebuilt rootfs images committed to the repository.
# These were built with cross-compiled static busybox and contain
# uname, getty, login, and all standard applets.
# To rebuild: see rootfs/busybox.config and scripts/rootfs.sh
COPY rootfs/prebuilt /opt/rootfs/prebuilt

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
