#!/bin/bash
# uboot-v1-build.sh — build RK3128 BSP U-Boot out-of-tree (attempt 1, stock-identical defconfig)
set -euo pipefail
SRC=/vol/uboot-src
BLD=/vol/uboot-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
export CROSS_COMPILE="$CROSS"
cd "$SRC"
make O="$BLD" rk3128_defconfig
make O="$BLD" -j"$(nproc)"
echo "=== BUILD OK ==="
ls -l "$BLD/u-boot" "$BLD/u-boot.bin" 2>/dev/null || true
"$CROSS"size "$BLD/u-boot" || true
