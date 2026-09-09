#!/usr/bin/env bash
exec > /workspace/work/v17-analysis18.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== context of rk_nandc_irq_init call in rk_ftl_arm_v7.S (which function?) ==='
sed -n '22800,22860p' rk_ftl_arm_v7.S | grep -n 'rk_ftl_init\|\.global\|rk_nandc_irq_init\|FUNC\|ENTRY' | head
sed -n '22820,22855p' rk_ftl_arm_v7.S | head -40
echo
echo '=== which blob is actually built? Makefile ==='
cat Makefile
echo
echo '=== does ftlv5 blob have its own wait/poll mechanism? (wait symbols) ==='
grep -c 'wait_for_nandc_xfer_completed\|wait_for_nandc_ready_completed' rk_ftlv5_arm32.S
grep -n 'bl\s\+wait_for_nandc' rk_ftlv5_arm32.S | head -5
