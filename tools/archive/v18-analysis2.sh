#!/usr/bin/env bash
exec > /workspace/work/v18-analysis2.log 2>&1
echo '=== mainline dtsi with inno-hdmi ==='
grep -rln 'inno-hdmi' /vol/kernel-src/arch/arm/boot/dts/ | head -5
echo
for f in /vol/kernel-src/arch/arm/boot/dts/rk3128.dtsi /vol/kernel-src/arch/arm/boot/dts/rk3036.dtsi; do
  [ -f "$f" ] && echo "--- $f ---" && grep -n -A16 'hdmi@20034000' "$f"
done
echo
echo '=== our driver: IRQ request + HPD + connector polled in inno_hdmi.c ==='
grep -n 'request_threaded_irq\|DRM_CONNECTOR_POLL\|hpd\|HDMI_STATUS\|detect(' /vol/kernel-src/drivers/gpu/drm/rockchip/inno_hdmi.c | head -30
