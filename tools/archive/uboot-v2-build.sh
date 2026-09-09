#!/bin/bash
# uboot-v2-build.sh — build từ commit 53cd91b73c (base chính xác của A26, KHÔNG có patch eMMC)
set -euo pipefail
SRC=/vol/uboot-a26-src
BLD=/vol/uboot-a26-build
CROSS=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
cd /vol/uboot-src
git worktree remove --force "$SRC" 2>/dev/null || true
rm -rf "$SRC" "$BLD"
git worktree add "$SRC" 53cd91b73c
mkdir -p "$BLD"
export CROSS_COMPILE="$CROSS"
cd "$SRC"
make O="$BLD" rk3128_defconfig
make O="$BLD" -j"$(nproc)"
echo "=== BUILD V2 OK ==="
ls -l "$BLD/u-boot.bin"
"$CROSS"size "$BLD/u-boot" || true
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$BLD/u-boot.bin" | head -1
echo "=== PACK V2 ==="
rm -f "$BLD/uboot-v2.img"
/vol/rkbin/tools/loaderimage --pack --uboot "$BLD/u-boot.bin" "$BLD/uboot-v2.img" 0x60000000
ls -l "$BLD/uboot-v2.img"
md5sum "$BLD/uboot-v2.img" "$BLD/u-boot.bin"
echo "=== so payload voi A26 (839104) ==="
stat -c%s "$BLD/u-boot.bin"
