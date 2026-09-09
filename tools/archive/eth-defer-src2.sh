#!/bin/bash
# eth-defer-src2.sh — doc body rk_gmac_setup/probe/clk_init + EPROBE_DEFER@432 + pltfr_init + kit files
set -uo pipefail
KS=/vol/kernel-src
SP=$KS/drivers/net/ethernet/stmicro/stmmac
echo "### A. stmmac_platform.c dong 400-460 (EPROBE_DEFER@432 thuoc ham nao):"
sed -n '400,460p' $SP/stmmac_platform.c
echo
echo "### B. stmmac_pltfr_init body:"
sed -n "/static int stmmac_pltfr_init/,/^}/p" $SP/stmmac_platform.c
echo
echo "### C. dwmac-rk: rk_gmac_setup body:"
sed -n "/static struct plat_stmmacenet_data \*rk_gmac_setup/,/^}/p" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
echo
echo "### D. dwmac-rk: rk_gmac_clk_init body:"
sed -n "/static int rk_gmac_clk_init/,/^}/p" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
echo
echo "### E. dwmac-rk: rk_gmac_probe body:"
sed -n "/static int rk_gmac_probe/,/^}/p" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c
echo
echo "### F. kernel .config location + STMMAC/PHY:"
for c in /vol/kernel-build/.config $KS/.config /vol/kernel-src/.config; do
  [ -f "$c" ] && { echo "== $c"; grep -E "CONFIG_STMMAC|CONFIG_DWMAC|CONFIG_MDIO_|CONFIG_PHYLIB|CONFIG_FIXED_PHY|CONFIG_REALTEK|CONFIG_ICPLUS|CONFIG_SMSC|CONFIG_MICREL|CONFIG_NATIONAL|CONFIG_REGULATOR_FIXED" "$c" | head -20; break; }
done
echo
echo "### G. kit misc/baseparamer so voi stock unpack:"
for f in /workspace/output/planb-stock-uboot/misc.img /workspace/work/stock-rkunpack/Image/misc.img /workspace/output/planb-stock-uboot/baseparamer-720P.img /workspace/work/stock-rkunpack/Image/baseparamer-720P.img; do
  [ -f "$f" ] && printf "%-58s %s %8s B\n" "$f" "$(md5sum "$f" | cut -c1-32)" "$(stat -c%s "$f")"
done
