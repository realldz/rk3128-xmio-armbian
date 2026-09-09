#!/bin/bash
# eth-defer-src.sh — tim diem -EPROBE_DEFER sau "PTP uses main clock" trong stmmac path
set -uo pipefail
KS=/vol/kernel-src
SP=$KS/drivers/net/ethernet/stmicro/stmmac
echo "### 1. cac dong print trong log o dau:"
grep -n "IRQ eth_lpi not found\|Deprecated MDIO bus\|PTP uses main clock" $SP/*.c
echo
echo "### 2. stmmac_probe_config_dt: tu PTP print den cuoi ham (defer points)"
awk '/PTP uses main clock/,/^}/' $SP/stmmac_platform.c | head -60
echo
echo "### 3. stmmac_pltfr_probe: sau stmmac_probe_config_dt"
grep -n -A40 "int stmmac_pltfr_probe" $SP/stmmac_platform.c | head -60
echo
echo "### 4. stmmac_dvr_probe: -EPROBE_DEFER / defer spots"
grep -n "EPROBE_DEFER" $SP/stmmac_main.c $SP/stmmac_mdio.c $SP/stmmac_ptp.c 2>/dev/null | head
echo
echo "### 5. dwmac-rk: rk_gmac_probe / rk_gmac_init clock handling rk3128"
grep -n -B2 -A25 "rk_gmac_init\b" $KS/drivers/net/ethernet/stmicro/stmmac/dwmac-rk.c | head -50
echo
echo "### 6. kernel config: PHY drivers + STMMAC"
grep -E "CONFIG_STMMAC|CONFIG_DWMAC|CONFIG_MDIO|CONFIG_PHYLIB|CONFIG_REALTEK_PHY|CONFIG_ICPLUS_PHY|CONFIG_SMSC_PHY|CONFIG_MICREL_PHY|CONFIG_NATIONAL_PHY|CONFIG_FIXED_PHY|CONFIG_LXT|CONFIG_DP838" $KS/.config 2>/dev/null | head -25
