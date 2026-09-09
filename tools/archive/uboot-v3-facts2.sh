#!/bin/bash
# uboot-v3-facts2.sh — uart2 pinctrl + debug uart init + sdmmc/emmc + chosen
set -uo pipefail
echo "############ 1. uart2-xfer pinctrl trong kernel DTS XMIO ############"
grep -n -A6 "uart2-xfer" /workspace/work/xmio-planb-v23.dts | head -12
echo "--- uart2 node trong kernel DTS XMIO:"
grep -n -A12 "serial@20068000" /workspace/work/xmio-planb-v23.dts | head -16

echo
echo "############ 2. board_debug_uart_init rk3128 (nguon) ############"
sed -n '35,80p' /vol/uboot-src/arch/arm/mach-rockchip/rk3128/rk3128.c

echo
echo "############ 3. sdmmc/emmc trong rk3128-evb.dts nguon ############"
grep -n -B1 -A3 "sdmmc\|emmc" /vol/uboot-src/arch/arm/dts/rk3128-evb.dts

echo
echo "############ 4. chosen/stdout-path dat o dau ############"
grep -rn "chosen\|stdout-path" /vol/uboot-src/arch/arm/dts/rk3128-evb.dts /vol/uboot-src/arch/arm/dts/rk3128.dtsi /vol/uboot-src/arch/arm/dts/rk3128-evb.dtsi 2>/dev/null | head

echo
echo "############ 5. aliases trong evb.dts ############"
grep -n -A8 "aliases" /vol/uboot-src/arch/arm/dts/rk3128-evb.dts /vol/uboot-src/arch/arm/dts/rk3128.dtsi 2>/dev/null | head -16
