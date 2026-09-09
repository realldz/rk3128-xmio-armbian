#!/bin/sh
# verify-update-img.sh — roundtrip verify cai update.img vua build
set -e
OUT=/workspace/output/planb-stock-uboot
V=/tmp/verify
TOOLS=/tmp/rk2918_tools

echo "=== 1. img_unpack release ==="
rm -rf $V && mkdir -p $V
$TOOLS/img_unpack $OUT/update_armbian_v28.img $V 2>&1 | tail -3
ls -la $V

echo "=== 2. loader md5 (BOOT vs stock MiniLoader) ==="
md5sum "$V/BOOT" "/tmp/stock-af-unpacked/rk3128MiniLoaderAll(L)_V2.25_ink.bin"

echo "=== 3. embedded AFP md5 ==="
md5sum "$V/update.img" /tmp/armbian-afp.img

echo "=== 4. afptool -unpack AFP ==="
mkdir -p $V/afp
$TOOLS/afptool -unpack "$V/update.img" $V/afp 2>&1 | tail -3

echo "=== 5. md5 tung component vs nguon ==="
md5sum $V/afp/boot.img $OUT/boot.img
md5sum $V/afp/resource.img $OUT/resource.img
md5sum $V/afp/uboot.img $OUT/uboot-stock.img
md5sum $V/afp/misc.img $OUT/misc.img
md5sum $V/afp/baseparamer-720P.img $OUT/baseparamer-720P.img
md5sum $V/afp/armbian_rootfs_26.2_xmio.img $OUT/armbian_rootfs_26.2_xmio.img

echo "=== 6. parameter content check ==="
diff $V/afp/parameter /tmp/apack/parameter && echo "parameter IDENTICAL"
grep -o '0x00300000@0x00017000(root)' $V/afp/parameter
