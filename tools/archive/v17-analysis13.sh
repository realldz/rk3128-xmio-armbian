#!/usr/bin/env bash
exec > /workspace/work/v17-analysis13.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== call sites of rknand_apply_bad_nand_policy ==='
grep -n 'rknand_apply_bad_nand_policy\|rknand_bad_nand_mode_enabled' *.c
echo
echo '=== context of each call (5 lines around) ==='
for L in $(grep -n 'rknand_apply_bad_nand_policy()' rk_nand_base.c rk_nand_blk.c | cut -d: -f1,2 | tr ':' ' '); do
  :; done
grep -n -B4 -A2 'rknand_apply_bad_nand_policy();' *.c
echo
echo '=== is it before or after rk_ftl_vendor_storage_init? ==='
grep -n 'rk_ftl_vendor_storage_init();' rk_nand_blk.c
