#!/usr/bin/env bash
set -uo pipefail
U=/vol/uboot-sb
echo "=== 1. vendor.c: backend + API ==="
grep -n -A6 'int vendor_storage_read\|int vendor_storage_write\|vendor_storage_init\|VendorStorageInit' "$U"/arch/arm/mach-rockchip/vendor.c | head -40
echo "=== 2. which storage backend (efuse/emmc/nand)? ==="
grep -n -i 'nand\|efuse\|emmc\|flash' "$U"/arch/arm/mach-rockchip/vendor.c | head -15
echo "=== 3. rk3128 config exists? ==="
ls "$U"/configs/ | grep -i 312
ls /vol/uboot-sb-build/.config 2>/dev/null && grep -E 'CONFIG_(TARGET|ROCKCHIP|SYS_BOARD|VENDOR)' /vol/uboot-sb-build/.config | head -10
echo "=== 4. board.c: usbethaddr generation (reads vendor MAC?) ==="
grep -n -B3 -A12 'usbethaddr' "$U"/arch/arm/mach-rockchip/board.c | head -30
echo "=== 5. uboot cmd for vendor? ==="
ls "$U"/cmd/ | grep -i -E 'vendor|sn|efuse' 
grep -rln 'vendor_storage' "$U"/cmd/ 2>/dev/null
echo "=== 6. does uboot-sb build dir have our box's FTL/nand? ==="
grep -E 'RK_NAND|NANDC|FTL' /vol/uboot-sb-build/.config 2>/dev/null | head
grep -rln 'rk_ftl\|nandc\|rk_nand' "$U"/drivers/ 2>/dev/null | head -8
