#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. who calls get_eth_addr (precedence vs DT MAC)? ==="
grep -n -B8 -A8 'get_eth_addr' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/stmmac_main.c | head -40
echo "=== 2. is assignment guarded? dwmac-rk 3320-3335 ==="
sed -n '3315,3340p' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
echo "=== 3. Kconfig deps ==="
grep -rn -A8 'config ROCKCHIP_VENDOR_STORAGE$' /vol/kernel-src/drivers/soc/rockchip/Kconfig /vol/kernel-src/drivers/*/Kconfig 2>/dev/null | head -20
grep -rn 'VENDOR_STORAGE' /vol/kernel-src/drivers/soc/rockchip/Kconfig | head
echo "=== 4. Makefile wiring ==="
grep -n 'vendor' /vol/kernel-src/drivers/soc/rockchip/Makefile
echo "=== 5. LAN_MAC_ID value ==="
grep -rn 'LAN_MAC_ID' /vol/kernel-src/include/ /vol/kernel-src/drivers/soc/rockchip/ 2>/dev/null | head -4
echo "=== 6. flash_vendor_storage backend needs ==="
grep -n 'module_init\|MODULE_LICENSE\|register_nandblk\|rknand\|RKFLASH' /vol/kernel-src/drivers/soc/rockchip/flash_vendor_storage.c | head -10
grep -rn 'flash_vendor_storage' /vol/kernel-src/drivers/soc/rockchip/Makefile /vol/kernel-src/drivers/soc/rockchip/Kconfig 2>/dev/null | head -6
echo "=== 7. userspace access (/dev/vendor_storage?) ==="
grep -n 'misc_register\|vendor_storage_misc\|devname' /vol/kernel-src/drivers/soc/rockchip/flash_vendor_storage.c /vol/kernel-src/drivers/soc/rockchip/rk_vendor_storage.c 2>/dev/null | head -8
