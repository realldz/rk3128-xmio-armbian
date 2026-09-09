#!/bin/bash
# eth-defer-diag.sh — gmac defer: node DTB + defer points + file table
set -uo pipefail
echo "############ 1. Node gmac trong DTB chuỗi v23/v24 (work/xmio-planb-v23.dts) ############"
awk '/ethernet@2008c000 \{/,/^\t\};/' /workspace/work/xmio-planb-v23.dts | head -60

echo
echo "############ 2. pinctrl gmac + gmac_clkin + mdio trong DTB ############"
grep -n "gmac" /workspace/work/xmio-planb-v23.dts | head -20

echo
echo "############ 3. Defer points: dwmac-rk rk3128 + stmmac_platform ############"
KS=/vol/kernel-src
grep -n "rk3128" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -10
sed -n '/static void rk3128_set_to_rmii/,/^}/p;/static void rk3128_set_to_rgmii/,/^}/p' $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -30
grep -n "EPROBE_DEFER\|-EPROBE\|dev_err.*clk\|clk_prepare_enable\|syscon_regmap" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -20
echo "--- stmmac_probe_config_dt clock/defer:"
grep -n "EPROBE_DEFER\|stmmaceth\|clk_get" $KS/drivers/net/ethernet/stmicro/stmmac/stmmac_platform.c | head -12
echo "--- stmmac_mdio register fail/defer:"
grep -n "EPROBE_DEFER\|ENODEV\|no PHY\|PHY not found" $KS/drivers/net/ethernet/stmicro/stmmac/stmmac_mdio.c | head -10

echo
echo "############ 4. Bang file: moi file boot/resource/rootfs/param trong workspace + md5 ############"
cd /workspace
for f in output/boot.img output/resource.img output/parameter.txt output/planb-boot/boot.img output/planb-resource/resource.img output/armbian_rootfs_v23_xmio.img output/nand-flash/resource.img output/nand-flash/boot.img work/stock-rkunpack/Image/resource.img work/stock-rkunpack/Image/boot.img work/stock-rkunpack/Image/misc.img work/stock-rkunpack/Image/baseparamer-720P.img; do
  if [ -f "$f" ]; then printf "%-55s %s  %10d bytes\n" "$f" "$(md5sum "$f" | cut -c1-32)" "$(stat -c%s "$f")"; fi
done
echo "--- tat ca file co 'boot' hoac 'resource' hoac 'rootfs' trong output/ (cap 1):"
ls -la output/ | grep -iE "boot|resource|rootfs|param" | head -20
ls -la output/planb-* 2>/dev/null | head -30
