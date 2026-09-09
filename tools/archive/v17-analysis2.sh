#!/usr/bin/env bash
exec > /workspace/work/v17-analysis2.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== ftl api header ==='
cat rk_ftl_api.h
echo
echo '=== gc thread tail after wait_event (what it does per tick) ==='
sed -n '545,575p' rk_nand_blk.c
echo
echo '=== rk_ftl_garbage_collect definition (blob call wrapper) ==='
grep -n -B3 -A8 'rk_ftl_garbage_collect' rk_nand_base.c | head -40
