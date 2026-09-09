#!/usr/bin/env bash
exec > /workspace/work/v10-analysis5.log 2>&1
K=/vol/kernel-src

echo "===== mach-rockchip Makefile ====="
cat $K/arch/arm/mach-rockchip/Makefile

echo "===== mach-rockchip dir ====="
ls $K/arch/arm/mach-rockchip/

echo "===== pm.c rockchip_suspend_init body ====="
sed -n '290,330p' $K/arch/arm/mach-rockchip/pm.c

echo "===== .config PM flags ====="
grep -n "CONFIG_PM_SLEEP\|CONFIG_PM=y\|CONFIG_SUSPEND\|CONFIG_ROCKCHIP_SUSPEND_MODE\|CONFIG_ARM_PSCI=" /vol/kernel-build/.config

echo "===== anchor A: Makefile guard (cat -A) ====="
grep -n -A2 -B1 "CONFIG_ARCH_ROCKCHIP)" $K/arch/arm/Makefile | cat -A

echo "===== anchor B: sip fn body (cat -A) ====="
sed -n '38,49p' $K/drivers/firmware/rockchip_sip.c | cat -A

echo "===== anchor C: platsmp prepare tail (cat -A) ====="
grep -n -B2 -A4 "pmu_set_power_domain(0 + i, false)" $K/arch/arm/mach-rockchip/platsmp.c | cat -A

echo "===== anchor D: rk3036 prepare head ====="
grep -n -A5 "rk3036_smp_prepare_cpus" $K/arch/arm/mach-rockchip/platsmp.c | head -12 | cat -A

echo "===== check existing V9DIAG in platsmp (from v9 patch) ====="
grep -n "V9DIAG" $K/arch/arm/mach-rockchip/platsmp.c

echo "===== sip: SIP_RET_SMC_UNKNOWN visible? include check ====="
grep -n "SIP_RET_SMC_UNKNOWN" $K/include/linux/rockchip/rockchip_sip.h

echo "===== who else calls sip_smc_get_dram_map / lastlog at runtime ====="
grep -rn "sip_smc_get_dram_map\|sip_smc_lastlog_request" $K/drivers $K/arch/arm --include=*.c | grep -v "rockchip_sip.c" | head

echo "===== rockchip_dmc / pm_config enabled in .config? ====="
grep -n "ROCKCHIP_DMC\|ROCKCHIP_PM_CONFIG\|ROCKCHIP_DMCDBG\|ROCKCHIP_AMP" /vol/kernel-build/.config
echo V10_ANALYSIS5_DONE
