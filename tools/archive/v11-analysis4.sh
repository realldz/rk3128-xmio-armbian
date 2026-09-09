#!/usr/bin/env bash
exec > /workspace/work/v11-analysis4.log 2>&1
B=/vol/kernel-build
K=/vol/kernel-src

echo "===== build dir drivers/rk_nand ====="
ls -la $B/drivers/rk_nand/ 2>/dev/null

echo "===== our kernel modules.builtin contains rk_nand? ====="
grep -n "rk_nand\|rknand" $B/modules.builtin 2>/dev/null
ls $B/ | head -20

echo "===== vmlinux symbols ====="
nm $B/vmlinux | grep -E "rknand_probe|rk_ftl_init|nand_blk_init|rknand_dev_init|rk_ftl_get_capacity" | head

echo "===== vmlinux strings: driver names ====="
strings $B/vmlinux | grep -E "rk29xxnand|rknand_root|rockchip,rk-nandc" | head

echo "===== .config vs build date ====="
ls -la $B/.config $B/vmlinux $B/arch/arm/boot/zImage
grep -n "CONFIG_RK_NAND" $B/include/config/auto.conf 2>/dev/null
grep -n "CONFIG_RK_NAND" $K/.config 2>/dev/null

echo "===== when was rk_nand last compiled (build log v10) ====="
grep -n "rk_nand\|rknand" /workspace/work/v10-build.log | head

echo "===== rknand_probe rest (clocks + ftl hw init) ====="
sed -n '460,560p' $K/drivers/rk_nand/rk_nand_base.c

echo "===== rk_nand_blk.c init function (module_init) ====="
sed -n '900,960p' $K/drivers/rk_nand/rk_nand_blk.c

echo "===== nand_ops->name value ====="
grep -n -B5 -A5 "nand_ops" $K/drivers/rk_nand/rk_nand_blk.c | grep -E "\.name|\"rknand\"|rknand" | head
echo V11_ANALYSIS4_DONE
