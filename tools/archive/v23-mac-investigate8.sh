#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. rk_vendor_storage.c FULL ==="
cat /vol/kernel-src/drivers/soc/rockchip/rk_vendor_storage.c
echo "=== 2. rk_nand_base.c: vendor refs ==="
grep -n -i 'vendor' /vol/kernel-src/drivers/rk_nand/rk_nand_base.c | head -15
echo "=== 3. rk_nand_blk.c: vendor refs ==="
grep -n -i 'vendor' /vol/kernel-src/drivers/rk_nand/rk_nand_blk.c | head -15
echo "=== 4. blob references flash_vendor_dev_ops_register? ==="
grep -rn 'flash_vendor_dev_ops_register\|rknand_vendor_storage_init' /vol/kernel-src/drivers/rk_nand/*.S | head -8
nm /vol/kernel-build/vmlinux | grep -E 'rknand_vendor|flash_vendor|rknand_get_vendor0' | head -8
echo "=== 5. misc/rkflash_vendor_storage.h exists? ==="
ls /vol/kernel-src/include/misc/ 2>/dev/null || echo NO-INCLUDE-MISC
find /vol/kernel-src/include -name 'rkflash_vendor_storage.h' 2>/dev/null
echo "=== 6. VENDOR_HEAD_TAG def ==="
grep -rn 'VENDOR_HEAD_TAG' /vol/kernel-src/include/ /vol/kernel-src/drivers/ 2>/dev/null | head -4
