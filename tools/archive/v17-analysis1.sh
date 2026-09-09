#!/usr/bin/env bash
exec > /workspace/work/v17-analysis1.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== procfs entries created by driver ==='
grep -n 'proc_create\|proc_mkdir\|rknand_create_procfs' rk_nand_blk.c
echo
echo '=== proc handler names / file names ==='
grep -n -B2 -A8 'rknand_create_procfs' rk_nand_blk.c | head -50
echo
echo '=== what does the ftl dump print ==='
grep -n 'seq_printf\|seq_puts' rk_nand_blk.c | head -20
