#!/usr/bin/env bash
exec > /workspace/work/v17-analysis3.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== proc fops read fn (lines 55-140) ==='
sed -n '55,140p' rk_nand_blk.c
