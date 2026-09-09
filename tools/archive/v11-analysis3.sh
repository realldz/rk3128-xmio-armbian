#!/usr/bin/env bash
exec > /workspace/work/v11-analysis3.log 2>&1
K=/vol/kernel-src
W=/workspace/work

echo "===== BLOCK_RKNAND symbol ====="
grep -rn "BLOCK_RKNAND" $K --include=Kconfig --include=Makefile --include=*.c --include=*.h | head

echo "===== THUMB2 / relevant .config ====="
grep -n "CONFIG_THUMB2_KERNEL\|CONFIG_RK_NAND\|CONFIG_RK_FLASH\|CONFIG_BLOCK_RKNAND\|CONFIG_BLK_DEV\|CONFIG_BLOCK=" /vol/kernel-build/.config

echo "===== rk_nand_base.c: of_match + probe + init ====="
grep -n "of_match\|of_device_id\|compatible\|platform_driver\|module_init\|arch_initcall\|subsys_initcall\|device_initcall\|probe\b" $K/drivers/rk_nand/rk_nand_base.c | head -25

echo "===== rk_nand_base.c probe body head ====="
grep -n -A40 "static int rk_nandc_probe\|static int nandc_probe\|_probe(struct platform_device" $K/drivers/rk_nand/rk_nand_base.c | head -80

echo "===== rk_nand_blk.h: nand_ops name ====="
grep -n "name\|rknand" $K/drivers/rk_nand/rk_nand_blk.h | head -20

echo "===== rk_nand_blk.c: init entry + FTL ordering ====="
grep -n "module_init\|arch_initcall\|device_initcall\|subsys_initcall\|nand_blk_init\|rk_ftl_init\|rk_ftl_get_capacity\|nand_parse_cmdline_part\|register_blkdev" $K/drivers/rk_nand/rk_nand_blk.c | head -25

echo "===== rk_nand_blk.c: nand_blk_init body ====="
grep -n -B3 -A60 "static int __init nand_blk_init" $K/drivers/rk_nand/rk_nand_blk.c

echo "===== rk_ftl_api.h: capacity + init api ====="
grep -n "rk_ftl_get_capacity\|rk_ftl_init\|ftl_init\|NAND_MAX" $K/drivers/rk_nand/rk_ftl_api.h $K/drivers/rk_nand/rk_nand_base.h 2>/dev/null | head

echo "===== rk_nand_base.c: FTL init call chain (grep ftl) ====="
grep -n "ftl\|FTL" $K/drivers/rk_nand/rk_nand_base.c | head -30

echo "===== initramfs: MODULES=most includes rknand module? (tristate m) ====="
grep -rn "rknand\|rk_nand" /tmp/initrd/lib/modules/6.6.89-rk3128+/modules.builtin 2>/dev/null | head
ls /tmp/initrd/lib/modules/6.6.89-rk3128+/kernel/drivers/ 2>/dev/null
echo V11_ANALYSIS3_DONE
