#!/usr/bin/env bash
exec > /workspace/work/v11-analysis5.log 2>&1
K=/vol/kernel-src

echo "===== rk_nand_blk.c: module_init / initcall at bottom ====="
tail -60 $K/drivers/rk_nand/rk_nand_blk.c

echo "===== rk_nand_blk.c: mytr struct definition ====="
grep -n -B3 -A20 "static struct nand_blk_ops mytr" $K/drivers/rk_nand/rk_nand_blk.c

echo "===== rknand_get_reg_addr ====="
grep -rn "rknand_get_reg_addr" $K/drivers/rk_nand/*.c $K/drivers/rk_nand/*.h
grep -n -B3 -A25 "void rknand_get_reg_addr\|rknand_get_reg_addr(unsigned" $K/drivers/rk_nand/rk_nand_base.c $K/drivers/rk_nand/rk_nand_blk.c 2>/dev/null | head -50

echo "===== who calls rknand_dev_init ====="
grep -rn "rknand_dev_init" $K/drivers/rk_nand/*.c

echo "===== rk_nand_base.c bottom: driver init + initcall level ====="
tail -40 $K/drivers/rk_nand/rk_nand_base.c

echo "===== rk_nand_base.c: irq handler + ftl hw init call ====="
grep -n "request_irq\|nandc_init\|rk_ftl_hw_init\|sysdata\|SYSD\|0x44535953\|idb" $K/drivers/rk_nand/rk_nand_base.c | head -20

echo "===== initcall order: of_platform vs rk_nand in System.map ====="
grep -E " __initcall" /vol/kernel-build/System.map | grep -iE "of_platform|rk_nand|rknand|nand_blk" | head

echo "===== initcall levels around ====="
grep -n "of_platform_default_populate_init\|rknand_driver_init\|rknand_blk_init\|nand_blk" /vol/kernel-build/System.map | head
echo V11_ANALYSIS5_DONE
