#!/usr/bin/env bash
exec > /workspace/work/v17-analysis6.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== rknand_bad_nand_level definition + default ==='
grep -rn 'rknand_bad_nand_level' *.c *.h | head -10
echo
echo '=== module_param section ==='
grep -n -B2 -A4 'module_param' rk_nand_base.c rk_nand_blk.c | head -40
echo
echo '=== who reads DT/other sources for bad nand ==='
grep -rn 'bad_nand\|bad-nand' *.c | head -10
