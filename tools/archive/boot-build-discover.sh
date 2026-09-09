#!/bin/bash
# boot-build-discover.sh — tim cach build kernel/boot v24.3 + doc block defer can patch
set -uo pipefail
echo "### 1. Block defer hien tai trong dwmac-rk.c (dong 3310-3335, hien tab):"
sed -n '3310,3335p' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | cat -A | head -28
echo
echo "### 2. Kernel build dir + .config:"
ls -d /vol/kernel-build 2>/dev/null && ls /vol/kernel-build/.config /vol/kernel-build/arch/arm/boot/zImage 2>/dev/null
echo
echo "### 3. Script nao build boot.img (mkbootimg):"
grep -ln "mkbootimg" /workspace/tools/*.sh 2>/dev/null | head -10
echo
echo "### 4. Script build gan nhat cho boot 5f61edcd:"
grep -ln "5f61edcd\|v24.3\|v24_3" /workspace/tools/*.sh 2>/dev/null | head -5
echo
echo "### 5. Rootfs v23 build script + cach mount:"
ls -la /workspace/tools/ | grep -iE "v23|v22|rootfs" | head -12
echo
echo "### 6. ramdisk dung cho boot.img:"
md5sum /workspace/output/planb-stock-uboot/initrd.img.gz 2>/dev/null
stat -c%s /workspace/output/planb-stock-uboot/initrd.img.gz
echo
echo "### 7. mkbootimg o dau:"
find /vol -maxdepth 3 -name "mkbootimg*" 2>/dev/null | head -3
