FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make bc bison flex libssl-dev libncurses-dev \
    libgmp-dev libmpc-dev libmpfr-dev \
    python3 python3-dev python3-pip \
    gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf \
    device-tree-compiler u-boot-tools mkbootimg \
    git wget curl xz-utils unzip zip cpio kmod rsync file less vim-tiny \
    parted dosfstools e2fsprogs libgnutls28-dev \
    libncurses5-dev pkg-config swig libpython3-dev \
    && rm -rf /var/lib/apt/lists/*

# afptool + image unpacking helpers for Rockchip images
WORKDIR /opt
RUN git clone --depth 1 https://github.com/rockchip-linux/rkflashtool.git /opt/rkflashtool \
    || true

# rkflashtool contains afptool? No - afptool is in rockchip-linux/tools; clone that too
RUN git clone --depth 1 https://github.com/rockchip-linux/tools.git /opt/rockchip-tools || true

# Build afptool if available
RUN if [ -d /opt/rockchip-tools/linux/Linux_Pack_Firmware/afptool_src ]; then \
      make -C /opt/rockchip-tools/linux/Linux_Pack_Firmware/afptool_src && \
      cp /opt/rockchip-tools/linux/Linux_Pack_Firmware/afptool_src/afptool /usr/local/bin/ ; \
    fi; \
    if [ -d /opt/rkflashtool ]; then \
      make -C /opt/rkflashtool/rkafpafptool 2>/dev/null || true; \
      make -C /opt/rkflashtool 2>/dev/null || true; \
      find /opt/rkflashtool -maxdepth 2 -type f -executable \( -name 'rk*' -o -name 'afptool' \) -exec cp {} /usr/local/bin/ \; || true; \
    fi; \
    which afptool rkunpack rkcrc 2>/dev/null || true

# rkdeveloptool (client for MaskROM/Loader flashing - useful for testing)
RUN git clone --depth 1 https://github.com/rockchip-linux/rkdeveloptool.git /opt/rkdeveloptool && \
    cd /opt/rkdeveloptool && \
    (./autogen.sh && ./configure && make -j$(nproc) && cp rkdeveloptool /usr/local/bin/) || \
    (apt-get update && apt-get install -y --no-install-recommends autoconf automake libtool pkg-config && \
     ./autogen.sh && ./configure && make -j$(nproc) && cp rkdeveloptool /usr/local/bin/) || true

WORKDIR /workspace
ENV ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
CMD ["/bin/bash"]
