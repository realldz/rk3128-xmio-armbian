#!/usr/bin/env bash
set -uo pipefail
U=/vol/uboot-sb
echo "=== 1. vendor.h IDs + write API ==="
cat "$U"/arch/arm/include/asm/arch-rockchip/vendor.h 2>/dev/null | head -40
echo "=== 2. vendor_storage_write exists? ==="
grep -n 'vendor_storage_write\|vendor_storage_read\|is_vendor_ready' "$U"/arch/arm/mach-rockchip/vendor.c | head -8
echo "=== 3. /vol/scripts: how was A26 uboot built? ==="
ls /vol/scripts/ 2>/dev/null
grep -l -i 'uboot\|rk3128' /vol/scripts/* 2>/dev/null | head -5
echo "=== 4. A26 uboot.img (nand-flash): has vendor/rkflash strings? ==="
strings /workspace/output/nand-flash/uboot.img 2>/dev/null | grep -i -E 'vendor|sftl|rkflash|nandc|FTL' | head -12
echo "=== 5. rk312x-slc-nand.config content ==="
cat "$U"/configs/rk312x-slc-nand.config 2>/dev/null
echo "=== 6. rk312x-rkflash.config ==="
cat "$U"/configs/rk312x-rkflash.config 2>/dev/null
echo "=== 7. rk3128_defconfig main options ==="
grep -E 'CONFIG_(TARGET|RKFLASH|VENDOR|ROCKCHIP_EFUSE|NET|DM_ETH|CMD)' "$U"/configs/rk3128_defconfig | head -20
