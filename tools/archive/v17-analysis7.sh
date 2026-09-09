#!/usr/bin/env bash
exec > /workspace/work/v17-analysis7.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== bad_nand full mechanism (lines 90-180) ==='
sed -n '90,180p' rk_nand_base.c
echo
echo '=== wait_busy_schedule usage (perf related?) ==='
grep -n 'rk_nand_wait_busy_schedule' rk_nand_base.c | head -10
sed -n '340,365p' rk_nand_base.c
