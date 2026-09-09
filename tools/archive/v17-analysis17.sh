#!/usr/bin/env bash
exec > /workspace/work/v17-analysis17.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== does the BLOB call rk_nandc_irq_init? ==='
grep -n 'rk_nandc_irq_init' rk_ftlv5_arm32.S
echo
echo '=== who calls rk_nandc_interrupt handler / irq_register ==='
grep -rn 'rk_nandc_irq_init\|rk_nandc_interrupt' *.c *.S *.h | grep -v 'analysis'
echo
echo '=== full rk_nandc_irq_init body ==='
sed -n '401,430p' rk_nand_base.c
echo
echo '=== blob: BL symbols related to irq ==='
grep -n 'bl\s\+rk_nandc' rk_ftlv5_arm32.S | head -10
echo
echo '=== what does blob do at xfer complete wait (flag set path) ==='
grep -n 'xfer_completed\|ready_completed' rk_ftlv5_arm32.S | head -10
