#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. flash_vendor_storage.c head (includes + _flash_read def) ==="
sed -n '1,58p' /vol/kernel-src/drivers/soc/rockchip/flash_vendor_storage.c
echo "=== 2. _flash_read definition anywhere ==="
grep -rn '_flash_read' /vol/kernel-src/include/ /vol/kernel-src/drivers/rkflash/ /vol/kernel-src/drivers/soc/rockchip/ 2>/dev/null | head -8
echo "=== 3. where is RK_NAND driver ==="
grep -rln 'config RK_NAND' /vol/kernel-src/drivers/ 2>/dev/null
grep -rn -A6 'config RK_NAND' /vol/kernel-src/drivers/*/Kconfig 2>/dev/null | head -12
echo "=== 4. RK_NAND vendor storage hooks ==="
RKNAND_DIR=$(grep -rln 'config RK_NAND' /vol/kernel-src/drivers/ 2>/dev/null | xargs dirname | head -1)
echo "dir: $RKNAND_DIR"
grep -rn -i 'vendor' "$RKNAND_DIR"/*.c "$RKNAND_DIR"/*.h 2>/dev/null | head -12
echo "=== 5. rkflash Makefile (what RK_FLASH=y builds) ==="
cat /vol/kernel-src/drivers/rkflash/Makefile
