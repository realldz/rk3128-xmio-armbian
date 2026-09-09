#!/usr/bin/env bash
exec > /workspace/work/v18-analysis3.log 2>&1
echo '=== mainline rk3128.dtsi hdmi node (rockchip/ subdir!) ==='
grep -n -A18 'hdmi@20034000' /vol/kernel-src/arch/arm/boot/dts/rockchip/rk3128.dtsi
echo
echo '=== our planb dts: hdmi pinctrl sub-nodes content (lines 1786-1802) ==='
sed -n '1780,1805p' /workspace/work/xmio-planb-v17.dts
echo
echo '=== inno_hdmi.c detect + irq + i2c ddc read (595-615, 920-950, 1180-1200) ==='
sed -n '595,615p' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c
sed -n '920,950p' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c
sed -n '1175,1210p' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c
