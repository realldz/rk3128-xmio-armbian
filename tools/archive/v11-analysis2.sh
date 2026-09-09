#!/usr/bin/env bash
exec > /workspace/work/v11-analysis2.log 2>&1
K=/vol/kernel-src

echo "===== drivers/rk_nand contents ====="
ls $K/drivers/rk_nand/
cat $K/drivers/rk_nand/Kconfig 2>/dev/null
cat $K/drivers/rk_nand/Makefile 2>/dev/null

echo "===== rk_nand_blk.c: cmdline parse function ====="
sed -n '650,760p' $K/drivers/rk_nand/rk_nand_blk.c

echo "===== rk_nand_blk.c: probe + device naming ====="
grep -n "rknand_\|add_disk\|alloc_disk\|register_blkdev\|platform_driver\|rk_nandc_probe\|MODULE_DEVICE_TABLE\|of_match" $K/drivers/rk_nand/rk_nand_blk.c | head -30

echo "===== drivers/mtd/rknand (old MTD version) ====="
ls $K/drivers/mtd/rknand/
cat $K/drivers/mtd/rknand/Kconfig
cat $K/drivers/mtd/rknand/Makefile
grep -n "rknand_root\|add_disk\|alloc_disk\|mtd_device_register\|platform_driver" $K/drivers/mtd/rknand/rknand_base_ko.c | head -20

echo "===== drivers/rkflash ====="
ls $K/drivers/rkflash/ 2>/dev/null | head
cat $K/drivers/rkflash/Kconfig 2>/dev/null
cat $K/drivers/rkflash/Makefile 2>/dev/null

echo "===== Kconfig wiring: who sources rk_nand? ====="
grep -n "rk_nand\|rkflash\|rknand" $K/drivers/Kconfig $K/drivers/Makefile | head

echo "===== mainline nfc compatibles (correct filename) ====="
grep -n "compatible" $K/drivers/mtd/nand/raw/rockchip-nand-controller.c | head -15

echo "===== DTB node verbatim: both nand nodes ====="
grep -n -A12 "nand-controller@10500000" $W/xmio-planb-v8.dts 2>/dev/null
W=/workspace/work
grep -n -A14 "nandc@10500000" $W/xmio-planb-v8.dts
echo V11_ANALYSIS2_DONE
