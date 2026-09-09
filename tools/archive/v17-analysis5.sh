#!/usr/bin/env bash
exec > /workspace/work/v17-analysis5.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== clock target selection logic (lines 465-500) ==='
sed -n '465,505p' rk_nand_base.c
echo
echo '=== how does the blob ask for clock rate (schedule_enable etc) ==='
sed -n '275,300p' rk_nand_base.c
echo
echo '=== boot log: what clock rate did nand probe report ==='
grep -n 'clk rate\|rknand_probe\|rknand:' /workspace/work/*.log 2>/dev/null | grep -i 'clk rate' | head -5
