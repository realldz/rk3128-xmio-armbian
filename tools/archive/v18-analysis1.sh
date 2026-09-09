#!/usr/bin/env bash
exec > /workspace/work/v18-analysis1.log 2>&1
echo '=== planb v17 dts: FULL hdmi node ==='
awk '/^\thdmi@20034000 \{/,/^\t\};/' /workspace/work/xmio-planb-v17.dts
echo
echo '=== mainline rk3128.dtsi / rk3036.dtsi: hdmi node reference ==='
grep -rn -A14 'inno-hdmi\|hdmi@20034000' /vol/kernel-src/arch/arm/boot/dts/rk3128.dtsi /vol/kernel-src/arch/arm/boot/dts/rk312x.dtsi /vol/kernel-src/arch/arm/boot/dts/rk3036.dtsi 2>/dev/null | head -40
echo
echo '=== stock dts: hdmi node ==='
grep -n -A12 'hdmi' /workspace/work/stock-dtbs/rk312x-stock.dts | grep -A12 -B1 '20034000' | head -30
echo
echo '=== pinctrl nodes for hdmi in planb dts ==='
grep -n 'hdmi' /workspace/work/xmio-planb-v17.dts | head -20
