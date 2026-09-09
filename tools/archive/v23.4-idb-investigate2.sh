#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. who calls rknand_get_idb_data / FlashReadIdbData ==="
grep -rn 'rknand_get_idb_data\|FlashReadIdbData\|g_idb_buffer' /vol/kernel-src/drivers/rk_nand/*.c /vol/kernel-src/drivers/rk_nand/*.h 2>/dev/null | head -10
echo "=== 2. idb data exposure (proc/ioctl) ==="
grep -rn -B2 -A10 'rknand_get_idb_data' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c 2>/dev/null | head -30
echo "=== 3. miniloader strings: mac/chipinfo related ==="
strings /workspace/output/planb-stock-uboot/"rk3128MiniLoaderAll(L)_V2.25_ink.bin" 2>/dev/null | grep -i -E 'mac|eth|chip.?info|idb' | head -15
echo "=== 4. stock uboot usbethaddr context ==="
strings /workspace/output/planb-stock-uboot/uboot-stock.img | grep -i -B1 -A1 'ethaddr\|eth' | head -15
echo "=== 5. blob idb read sizes (FlashReadIdbData raw bytes?) ==="
nm /vol/kernel-build/vmlinux | grep -E 'FlashReadIdb|idb' | head -8
