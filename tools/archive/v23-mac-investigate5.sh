#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. rk_get_eth_addr full body ==="
sed -n '3250,3300p' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
echo "=== 2. RK_FLASH Kconfig ==="
grep -rn -B2 -A8 'config RK_FLASH' /vol/kernel-src/drivers/ 2>/dev/null | head -20
echo "=== 3. current rknand/flash configs ==="
grep -E 'RK_FLASH|RK_NAND|RKNAND|RKFLASH' /vol/kernel-build/.config
echo "=== 4. rkflash dir? ==="
ls /vol/kernel-src/drivers/rkflash/ 2>/dev/null | head -8 || echo NO-RKFLASH-DIR
ls /vol/kernel-src/drivers/block/ 2>/dev/null | grep -i 'rk\|nand'
echo "=== 5. flash_vendor_storage flash API calls ==="
grep -n 'flash_\|rknand_\|sys_'; sed -n '60,120p' /vol/kernel-src/drivers/soc/rockchip/flash_vendor_storage.c
