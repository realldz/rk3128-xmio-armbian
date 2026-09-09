#!/usr/bin/env bash
set -uo pipefail
U=/vol/uboot-sb
echo "=== 1. f_rockusb: command table + vendor ops ==="
grep -n -B2 -A4 'RKUSB_CMD\|rkusb_do_vendor\|vendor' "$U"/drivers/usb/gadget/f_rockusb.c | grep -A4 -B2 -i 'vendor\|0x0[0-9a-f]' | head -40
echo "=== 2. vendor.c 850-1040 (who writes vendor) ==="
sed -n '850,1040p' "$U"/arch/arm/mach-rockchip/vendor.c | grep -n -B4 -A10 'vendor_storage_write' | head -50
echo "=== 3. rk3128_defconfig: vendor/eth/net ==="
grep -n -i 'vendor\|eth\|ethaddr\|usbether\|rockusb\|fastboot' "$U"/configs/rk3128_defconfig | head -15
echo "=== 4. NOTES: A26 flash recipe (trust/uboot/idbloader offsets) ==="
grep -n -B2 -A8 'trust.img\|idbloader' /workspace/NOTES.md | head -40
