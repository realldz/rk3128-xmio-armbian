#!/usr/bin/env bash
exec > /workspace/work/v10-analysis1.log 2>&1
K=/vol/kernel-src

echo "===== locate __invoke_sip_fn_smc ====="
grep -rn "__invoke_sip_fn_smc" $K --include=*.c --include=*.h | head

echo "===== sip file ====="
F=$(grep -rln "__invoke_sip_fn_smc" $K/drivers | head -1)
echo "FILE: $F"
sed -n '1,120p' $F

echo "===== callers of sip smc ====="
grep -rn "rockchip_sip_smc\|sip_smc_request_share_mem\|SIP_LOADER_PROTECT\|0x82000009" $K --include=*.c --include=*.h | head -20

echo "===== who calls sip inside drm init ====="
grep -rn "sip" $K/drivers/gpu/drm/rockchip/rockchip_drm_drv.c | head
grep -rn "loader.protect\|loader_protect" $K/drivers/gpu/drm/rockchip/*.c | head

echo "===== Makefile guard ====="
sed -n '215,222p' $K/arch/arm/Makefile

echo "===== platsmp CPU_METHOD_OF_DECLARE ====="
grep -n "CPU_METHOD_OF_DECLARE\|rockchip_smp_ops\|struct smp_operations" $K/arch/arm/mach-rockchip/platsmp.c | head

echo "===== rockchip.c machine desc ====="
grep -n "DT_MACHINE_START\|MACHINE_START\|smp\b\|dt_compat" $K/arch/arm/mach-rockchip/rockchip.c | head

echo "===== v9diag.h busywait current ====="
grep -n "40000000" /vol/kernel-src/include/linux/v9diag.h
echo V10_ANALYSIS1_DONE
