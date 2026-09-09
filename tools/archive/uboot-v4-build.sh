#!/bin/bash
# uboot-v4-build.sh — v3 patches + toolchain linaro 6.3.1 của tác giả
set -euo pipefail
URL=https://releases.linaro.org/components/toolchain/binaries/6.3-2017.05/arm-linux-gnueabihf/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
TGZ=/vol/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz
DST=/vol/toolchain-linaro

if [ ! -x "$DST/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc" ]; then
  echo "=== TAI linaro 6.3.1 ==="
  wget -c -q --timeout=30 --tries=3 -O "$TGZ" "$URL"
  ls -l "$TGZ"
  mkdir -p "$DST"
  tar -xf "$TGZ" -C "$DST"
fi
GCC=$DST/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-gcc
"$GCC" --version | head -1

echo "=== BUILD V4 (worktree v3 da patch, toolchain linaro) ==="
SRC=/vol/uboot-v3-src
BLD=/vol/uboot-v4-build
rm -rf "$BLD"
export CROSS_COMPILE=$DST/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-
cd "$SRC"
git --no-pager diff --stat | tail -2
make O="$BLD" rk3128_defconfig
make O="$BLD" -j"$(nproc)"
echo "=== BUILD V4 OK ==="
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$BLD/u-boot.bin" | head -1
ls -l "$BLD/u-boot.bin"

echo "=== PACK V4 ==="
rm -f "$BLD/uboot-v4.img"
/vol/rkbin/tools/loaderimage --pack --uboot "$BLD/u-boot.bin" "$BLD/uboot-v4.img" 0x60000000
ls -l "$BLD/uboot-v4.img"
md5sum "$BLD/uboot-v4.img" "$BLD/u-boot.bin"
mkdir -p /workspace/output/planb-uboot-v4
cp "$BLD/uboot-v4.img" "$BLD/u-boot.bin" "$BLD/.config" /workspace/output/planb-uboot-v4/
cd /workspace/output/planb-uboot-v4
mv u-boot.bin u-boot-v4.bin
mv .config uboot-v4.config
md5sum *
