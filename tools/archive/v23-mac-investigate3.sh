#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. dwmac-rk vendor storage MAC support ==="
grep -n -i 'vendor\|eth_addr\|get_mac' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -15
echo "=== 2. rk_vendor driver present? ==="
ls /vol/kernel-src/drivers/soc/rockchip/ 2>/dev/null
grep -rn 'rk_vendor_read\|RK_VENDOR' /vol/kernel-src/drivers/soc/rockchip/*.c 2>/dev/null | head -8
grep -n 'VENDOR_STORAGE' /vol/kernel-build/.config
echo "=== 3. rk312x.dtsi: efuse full node ==="
sed -n '1205,1250p' /vol/kernel-src/arch/arm/boot/dts/rockchip/rk312x.dtsi
echo "=== 4. rk312x.dtsi: gmac node (mac source?) ==="
grep -n -B2 -A25 'gmac: ethernet' /vol/kernel-src/arch/arm/boot/dts/rockchip/rk312x.dtsi | head -40
echo "=== 5. PCLK_EFUSE clock id ==="
grep -n 'PCLK_EFUSE' /vol/kernel-src/include/dt-bindings/clock/rk3128-cru.h
echo "=== 6. our DTS: cru node phandle ==="
grep -n 'cru: \|cru@20000000' /workspace/work/xmio-planb-v19.4.dts | head -4
grep -n -A3 'cru@20000000' /workspace/work/xmio-planb-v19.4.dts | head -8
echo "=== 7. vendor storage ioctls/userspace ==="
grep -rn 'vendor_storage\|rk_vendor' /vol/kernel-src/drivers/char/*.c 2>/dev/null | head -5
ls /vol/kernel-src/drivers/char/ | grep -i vendor
