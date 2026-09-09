#!/usr/bin/env bash
exec > /workspace/work/v17-analysis4.log 2>&1
cd /vol/kernel-src/drivers/rk_nand
echo '=== clock handling in nand base ==='
grep -n 'clk\|rate\|24M\|150M\|300M' rk_nand_base.c | head -25
echo
echo '=== DMA or PIO ==='
grep -n 'dma\|DMA' rk_nand_base.c | head -15
echo
echo '=== schedule_enable_config + slc mode strings ==='
grep -rn 'slc mode\|schedule_enable' *.c *.S 2>/dev/null | grep -v '\.S:' | head -8
grep -c 'slc mode' rk_ftlv5_arm32.S
echo
echo '=== nandc reg base / clock setup in blob init path (rk_nand_base.c tail) ==='
grep -n 'nandc0\|0x10500000\|NANDC' rk_nand_base.c | head -15
