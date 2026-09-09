#!/usr/bin/env bash
exec > /workspace/work/v10-analysis6.log 2>&1
K=/vol/kernel-src

echo "===== core.h ====="
cat $K/arch/arm/mach-rockchip/core.h

echo "===== headsmp.S ====="
cat $K/arch/arm/mach-rockchip/headsmp.S

echo "===== clk-ddr.c: direct smc context ====="
grep -n -B5 -A15 "arm_smccc_smc" $K/drivers/clk/rockchip/clk-ddr.c | head -60
grep -n "CLK_OF_DECLARE\|platform_driver\|module_init\|of_match" $K/drivers/clk/rockchip/clk-ddr.c | head

echo "===== rockchip_dmc.c: direct smc lines ====="
grep -n "arm_smccc_smc" $K/drivers/devfreq/rockchip_dmc.c
grep -n "sip_smc" $K/drivers/devfreq/rockchip_dmc.c | head
grep -n "of_match_table\|compatible\|OF_DEV_AUXDATA\|platform_driver_register\|rockchip_dmc_driver_register\|initcall" $K/drivers/devfreq/rockchip_dmc.c | head -10

echo "===== dmc compatible probe trigger: DTB has dmc node? ====="
grep -n "dmc\|ddr" /workspace/work/xmio-planb-v8.dts | head

echo "===== mpp vpu reset via sip? ====="
grep -rn "sip_smc_vpu_reset\|PSCI_SIP_VPU_RESET" $K/drivers/staging $K/drivers/mpp 2>/dev/null | head
grep -rln "rk3128.*mpp\|mpp.*rk3128" $K/drivers/staging 2>/dev/null | head -3

echo "===== CONFIG_CPU_RK3288 / CPU_RV1106 in .config ====="
grep -n "CONFIG_CPU_RK3288\|CONFIG_CPU_RV1106\|CONFIG_CPU_RK3036\|CONFIG_CPU_RK3066\|CONFIG_CPU_RK3188\|CONFIG_CPU_RK322X" /vol/kernel-build/.config

echo "===== arm,armv7-timer in v8 dts + arch timer nodes ====="
grep -n -B2 -A8 "armv7-timer" /workspace/work/xmio-planb-v8.dts
echo V10_ANALYSIS6_DONE
