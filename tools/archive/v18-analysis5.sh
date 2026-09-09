#!/usr/bin/env bash
exec > /workspace/work/v18-analysis4.log 2>&1
echo '=== mainline dtsi FULL hdmi node incl ports + vop endpoint ==='
sed -n '28,75p' /vol/kernel-src/arch/arm/boot/dts/rockchip/rk3128.dtsi
echo
echo '=== mainline vop node: out endpoints ==='
grep -n -B2 -A20 'vop@1010e000\|vop: vop' /vol/kernel-src/arch/arm/boot/dts/rockchip/rk3128.dtsi | head -40
echo
echo '=== our dts: vop node ports/endpoint@2 ==='
awk '/^\tvop@1010e000 \{/,/^\t\};/' /workspace/work/xmio-planb-v17.dts
echo
echo '=== phandle 0x10 = vop out endpoint? ==='
grep -n -B3 'phandle = <0x10>;' /workspace/work/xmio-planb-v17.dts | head -10
