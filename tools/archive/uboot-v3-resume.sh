#!/bin/bash
# uboot-v3-resume.sh — build tiếp trên worktree v3 đã patch, rồi pack + verify
set -euo pipefail
SRC=/vol/uboot-v3-src
BLD=/vol/uboot-v3-build
export CROSS_COMPILE=/vol/toolchain/gcc-arm-10.3-2021.07-x86_64-arm-none-linux-gnueabihf/bin/arm-none-linux-gnueabihf-
cd "$SRC"
git --no-pager diff --stat | tail -3
make O="$BLD" -j"$(nproc)"
echo "=== BUILD V3 OK ==="
grep -ao 'U-Boot 20[0-9.]*[0-9a-zA-Z .:-]*' "$BLD/u-boot.bin" | head -1
ls -l "$BLD/u-boot.bin"

echo "=== VERIFY DTB NHUNG ==="
"$BLD/tools/dtc" -I dtb -O dts -o /tmp/v3.dts "$BLD/u-boot.dtb" 2>/dev/null || dtc -I dtb -O dts -o /tmp/v3.dts "$BLD/u-boot.dtb"
echo "--- uart2 node:"
grep -n -A4 'serial@20068000' /tmp/v3.dts | head -8
echo "--- chosen:"
grep -n -A3 '\bchosen\b' /tmp/v3.dts | head -6
echo "--- sdmmc/emmc status:"
grep -n -A6 'sdmmc@\|emmc@' /tmp/v3.dts | grep -E 'sdmmc@|emmc@|status' | head -8

echo "=== PACK V3 ==="
rm -f "$BLD/uboot-v3.img"
/vol/rkbin/tools/loaderimage --pack --uboot "$BLD/u-boot.bin" "$BLD/uboot-v3.img" 0x60000000
ls -l "$BLD/uboot-v3.img"
md5sum "$BLD/uboot-v3.img" "$BLD/u-boot.bin" "$BLD/u-boot.dtb"
