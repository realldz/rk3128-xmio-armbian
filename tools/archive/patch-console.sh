#!/usr/bin/env bash
# Patch armbianEnv.txt in both images: kernel log to UART2 + UART1 + HDMI.
exec > /workspace/work/patch-console.log 2>&1
set -e
LINE='extraargs=coherent_pool=2M console=ttyS2,115200 console=ttyS1,115200 console=tty1'

echo "=== NAND rootfs ==="
mkdir -p /mnt/n
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o rw $L /mnt/n
sed -i "s|^extraargs=.*|${LINE}|" /mnt/n/boot/armbianEnv.txt
cat /mnt/n/boot/armbianEnv.txt
sync; umount /mnt/n; losetup -d $L

echo "=== SD image ==="
mkdir -p /mnt/s
L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o rw $L /mnt/s
sed -i "s|^extraargs=.*|${LINE}|" /mnt/s/boot/armbianEnv.txt
cat /mnt/s/boot/armbianEnv.txt
sync; umount /mnt/s; losetup -d $L

echo PATCH_CONSOLE_DONE
