#!/usr/bin/env bash
exec > /workspace/work/v11-analysis1.log 2>&1
K=/vol/kernel-src
W=/workspace/work

echo "===== grep rknand / rk29xxnand in kernel source ====="
grep -rln "rknand" $K/drivers 2>/dev/null | head
grep -rn "rk29xxnand" $K/drivers $K/arch/arm --include=*.c --include=*.h 2>/dev/null | head

echo "===== MTD/NAND related configs in .config ====="
grep -n "CONFIG_MTD\|CONFIG_RKNAND\|CONFIG_NAND\|CONFIG_UBIFS\|CONFIG_UBI=\|CONFIG_BLK_DEV_RAM" /vol/kernel-build/.config | grep -v "^.*is not set" | head -40

echo "===== mainline rockchip nfc driver compatibles ====="
grep -n "compatible" $K/drivers/mtd/nand/raw/rockchip-nfc-controller.c 2>/dev/null | head -20

echo "===== nand/nfc nodes in planb v8 dts ====="
grep -n -i "nand\|nfc" $W/xmio-planb-v8.dts | head

echo "===== rootfs image device expectation: what is initrd.img.gz ====="
ls -la /workspace/output/planb-stock-uboot/initrd.img.gz
file /workspace/output/planb-stock-uboot/initrd.img.gz

echo "===== unpack initrd to /tmp/initrd ====="
rm -rf /tmp/initrd; mkdir -p /tmp/initrd
gzip -dc /workspace/output/planb-stock-uboot/initrd.img.gz | cpio -idm -D /tmp/initrd 2>/dev/null
ls /tmp/initrd/
echo "----- /init head -----"
sed -n '1,60p' /tmp/initrd/init 2>/dev/null
echo "----- initramfs conf for root/resume/modules -----"
ls /tmp/initrd/conf/ 2>/dev/null
cat /tmp/initrd/conf/initramfs.conf 2>/dev/null | head -20
cat /tmp/initrd/conf/cmdline.root 2>/dev/null
echo "----- initramfs modules for rk nand? -----"
find /tmp/initrd/lib/modules -name "*nand*" -o -name "*rknand*" 2>/dev/null | head
find /tmp/initrd/lib/modules -name "*.ko*" 2>/dev/null | head -20

echo "===== /dev nodes in initrd ====="
ls /tmp/initrd/dev/ 2>/dev/null | head

echo "===== does initramfs scripts wait for root? ====="
grep -rn "rknand" /tmp/initrd/ 2>/dev/null | head
echo V11_ANALYSIS1_DONE
