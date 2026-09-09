#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. full RK_* configs (NAND stack identity) ==="
grep -E 'CONFIG_RK_(NAND|SFTL|FLASH|SFC|NANDC)|BLOCK_RKNAND|CONFIG_RK_BOOT' /vol/kernel-build/.config
echo "=== 2. drivers/rk_nand contents ==="
ls /vol/kernel-src/drivers/rk_nand/
echo "=== 3. rk_nand Kconfig + Makefile ==="
cat /vol/kernel-src/drivers/rk_nand/Kconfig /vol/kernel-src/drivers/rk_nand/Makefile 2>/dev/null
echo "=== 4. vendor hooks in rk_nand ==="
grep -rn -i 'vendor\|flash_vendor_dev_ops_register' /vol/kernel-src/drivers/rk_nand/ | head -12
echo "=== 5. who calls flash_vendor_dev_ops_register (whole tree) ==="
grep -rln 'flash_vendor_dev_ops_register' /vol/kernel-src/drivers/ | head
echo "=== 6. FTL blob symbols in build (sftl_vendor_*) ==="
nm /vol/kernel-build/vmlinux 2>/dev/null | grep -i 'sftl_vendor\|vendor_read\|vendor_write' | head -8
grep -rn 'sftl_vendor_read\|sftl_vendor_write' /vol/kernel-src/drivers/rk_nand/ 2>/dev/null | head -6
echo "=== 7. rk_nand: what files build under CONFIG_RK_NAND ==="
grep -rn 'obj-' /vol/kernel-src/drivers/rk_nand/Makefile 2>/dev/null | head
