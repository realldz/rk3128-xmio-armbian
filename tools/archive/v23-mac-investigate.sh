#!/usr/bin/env bash
set -uo pipefail
echo "=== 1. NVMEM/EFUSE in .config ==="
grep -E 'CONFIG_NVMEM|CONFIG_EFUSE|CONFIG_ROCKCHIP' /vol/kernel-build/.config | grep -v 'not set'
grep -E 'CONFIG_NVMEM|CONFIG_ROCKCHIP_EFUSE' /vol/kernel-build/.config | head -8
echo "=== 2. mainline rk3128.dtsi efuse node ==="
ls /vol/kernel-src/arch/arm/boot/dts/ | grep -E '^rk312[0-9]' || echo NO-RK3128-DTSI
grep -n -A12 'efuse' /vol/kernel-src/arch/arm/boot/dts/rk3128.dtsi 2>/dev/null || echo NO-EFUSE-IN-DTSI
echo "=== 3. our v19.4 dts: ethernet + mac ==="
grep -n 'local-mac-address\|mac-address\|ethernet@\|gmac' /workspace/work/xmio-planb-v19.4.dts | head -10
echo "=== 4. dwmac-rk rk3128 support ==="
grep -n 'rk3128' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -5
echo "=== 5. stmmac nvmem mac read ==="
grep -n 'nvmem\|of_get_mac_address' /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/stmmac_platform.c /vol/kernel-src/drivers/net/ethernet/stmicro/stmmac/stmmac_main.c 2>/dev/null | head -8
echo "=== 6. of_net.c MAC precedence ==="
grep -n -B2 -A6 'of_get_mac_addr_nvmem\|local-mac-address' /vol/kernel-src/net/core/of_net.c | head -40
echo "=== 7. rockchip-efuse driver compatibles ==="
grep -n 'compatible' /vol/kernel-src/drivers/nvmem/rockchip-efuse.c 2>/dev/null | head -10
ls /vol/kernel-src/drivers/nvmem/ | grep -i rockchip
echo "=== 8. stock uboot strings: ethaddr/efuse ==="
strings /workspace/output/planb-stock-uboot/uboot-stock.img 2>/dev/null | grep -iE 'ethaddr|efuse' | head -8
echo "=== 9. stock decompiled dts: efuse/mac ==="
ls /workspace/work/ | grep -iE 'stock|orig' | head -8
for f in /workspace/work/*stock*.dts /workspace/work/*orig*.dts; do
  [ -f "$f" ] && { echo "-- $f"; grep -n 'efuse\|mac-address\|ethernet@' "$f" | head -12; }
done
