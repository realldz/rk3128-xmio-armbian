#!/usr/bin/env bash
exec > /workspace/work/v10-analysis2.log 2>&1
K=/vol/kernel-src

echo "===== Makefile guard exact bytes ====="
sed -n '216,222p' $K/arch/arm/Makefile | cat -A

echo "===== SIP_RET defines ====="
grep -rn "SIP_RET_" $K/include/linux/rockchip/rockchip_sip.h $K/include/soc/rockchip/rockchip_sip.h 2>/dev/null | head

echo "===== rockchip_sip.c 150-360 (share mem + hdcp) ====="
sed -n '150,360p' $K/drivers/firmware/rockchip_sip.c

echo "===== who calls hdcp sip ====="
grep -rn "sip_smc_hdcp\|SHARE_PAGE_TYPE_HDCP" $K/drivers --include=*.c | head

echo "===== rockchip_drm_init body ====="
awk '/^static int __init rockchip_drm_init/,/^}/' $K/drivers/gpu/drm/rockchip/rockchip_drm_drv.c

echo "===== failed to parse loader memory context ====="
grep -n "failed to parse loader memory" $K/drivers/gpu/drm/rockchip/rockchip_drm_drv.c

echo "===== platsmp.c 90-380 ====="
sed -n '90,380p' $K/arch/arm/mach-rockchip/platsmp.c

echo "===== rockchip.c full ====="
cat $K/arch/arm/mach-rockchip/rockchip.c

echo "===== planb dts file name ====="
grep -rn "rk3128-xmio-planb" $K/arch/arm/boot/dts/rockchip/ 2>/dev/null | head -3
ls $K/arch/arm/boot/dts/rockchip/ | grep -i xmio

echo "===== pm-config / dmc nodes in planb dts ====="
grep -n "rockchip,pm-config\|rockchip,dmc\|rockchip-suspend" $K/arch/arm/boot/dts/rockchip/rk3128-xmio-planb.dts 2>/dev/null
echo V10_ANALYSIS2_DONE
