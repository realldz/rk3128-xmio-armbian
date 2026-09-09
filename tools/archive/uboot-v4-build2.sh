#!/bin/bash
# uboot-v4-build2.sh — linaro 6.3.1 tu gitlab firefly (mirror chinh chu) + build v4
set -euo pipefail
REPO=https://gitlab.com/firefly-linux/prebuilts/gcc/linux-x86/arm/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.git
DST=/vol/toolchain-linaro/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf
rm -f /vol/gcc-linaro-6.3.1-2017.05-x86_64_arm-linux-gnueabihf.tar.xz

if [ ! -x "$DST/bin/arm-linux-gnueabihf-gcc" ]; then
  echo "=== CLONE linaro 6.3.1 tu gitlab firefly ==="
  rm -rf "$DST"
  git clone --depth 1 "$REPO" "$DST"
fi
GCC=$DST/bin/arm-linux-gnueabihf-gcc
ls -l "$GCC"
"$GCC" --version | head -1

echo "=== BUILD V4 (worktree v3 da patch, toolchain linaro 6.3.1) ==="
SRC=/vol/uboot-v3-src
BLD=/vol/uboot-v4-build
rm -rf "$BLD"
export CROSS_COMPILE=$DST/bin/arm-linux-gnueabihf-
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
