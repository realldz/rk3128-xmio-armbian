#!/usr/bin/env bash
exec > /workspace/work/v10-analysis3.log 2>&1
K=/vol/kernel-src

echo "===== platsmp.c 1-90 (pmu_set_power_domain head) ====="
sed -n '1,90p' $K/arch/arm/mach-rockchip/platsmp.c

echo "===== IS_SIP_ERROR define ====="
grep -rn "define IS_SIP_ERROR" $K/include/

echo "===== rockchip_gem_get_ddr_info ====="
grep -n "rockchip_gem_get_ddr_info" $K/drivers/gpu/drm/rockchip/*.c
awk '/rockchip_gem_get_ddr_info/,/^}/' $K/drivers/gpu/drm/rockchip/rockchip_drm_gem.c | head -40

echo "===== direct arm_smccc_smc callers outside sip ====="
grep -rln "arm_smccc_smc" $K/drivers --include=*.c | head -20

echo "===== callers of sip_smc_amp_config / pvtpll ====="
grep -rn "sip_smc_amp_config\|sip_smc_get_amp_info\|sip_smc_get_pvtpll_info\|sip_smc_pvtpll_config" $K/drivers --include=*.c | grep -v "rockchip_sip.c" | head

echo "===== Generic DT based system fallback ====="
grep -rn "Generic DT based system" $K/arch/arm --include=*.c | head -3

echo "===== rk3128-xmio.dts root + cpus ====="
grep -n "compatible\|enable-method\|smp-sram\|rk3066-smp-sram" $K/arch/arm/boot/dts/rockchip/rk3128-xmio.dts | head -30

echo "===== suspend init + config ====="
grep -n "rockchip_suspend_init" $K/arch/arm/mach-rockchip/pm.c $K/arch/arm/mach-rockchip/core.h 2>/dev/null | head
grep -n "CONFIG_ROCKCHIP_SUSPEND_MODE\|CONFIG_HOTPLUG_CPU\|CONFIG_ARM_PSCI\|CONFIG_ARCH_ROCKCHIP" /vol/kernel-build/.config

echo "===== planb build script dts source ====="
grep -n "dts\|dtb" /workspace/tools/planb-v8.sh 2>/dev/null | head -10
ls /workspace/tools/ | grep planb
echo V10_ANALYSIS3_DONE
