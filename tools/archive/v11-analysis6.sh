#!/usr/bin/env bash
exec > /workspace/work/v11-analysis6.log 2>&1
K=/vol/kernel-src
B=/vol/kernel-build

echo "===== RKNAND version string ====="
grep -n "RKNAND_VERSION_AND_DATE" $K/drivers/rk_nand/rk_nand_base.c $K/drivers/rk_nand/rk_nand_base.h | head -4
grep -n -A3 "define RKNAND_VERSION_AND_DATE" $K/drivers/rk_nand/rk_nand_base.h

echo "===== prints in nand_blk_register path ====="
sed -n '790,900p' $K/drivers/rk_nand/rk_nand_blk.c

echo "===== strings in vmlinux: rknand / FTL messages ====="
strings $B/vmlinux | grep -iE "^rknand|nand flash|ftl|flash id|bad block|nandc" | head -40

echo "===== rk_ftl blob strings (init messages) ====="
strings $B/drivers/rk_nand/rk_zftl_arm32.o 2>/dev/null | head -30
strings $B/drivers/rk_nand/rk_ftlv5_arm32.o 2>/dev/null | head -30

echo "===== who prints 'Nand flash flush ok' etc ====="
grep -rn "pr_info\|pr_err\|printk" $K/drivers/rk_nand/rk_nand_blk.c | head -20

echo "===== probe: what if hclk missing - deferred? ====="
grep -rn "EPROBE_DEFER" $K/drivers/rk_nand/*.c | head

echo "===== does nand_blk_register create disks via nand_add_dev with parts ====="
grep -n -B2 -A8 "g_max_part_num" $K/drivers/rk_nand/rk_nand_blk.c | head -50
echo V11_ANALYSIS6_DONE
