#!/usr/bin/env bash
exec > /workspace/work/v16-analysis17.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== vendor storage init call site ==='
grep -n -B3 -A6 'rk_ftl_vendor_storage_init' rk_nand_blk.c
echo
echo '=== gc thread spawn site ==='
grep -n -B2 -A4 'nand_gc_thread' rk_nand_blk.c | head -30
echo
echo '=== static decl area (line 60-75) ==='
sed -n '60,75p' rk_nand_blk.c
