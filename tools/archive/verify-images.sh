#!/usr/bin/env bash
# Verify XMIO images; log to /workspace/work/verify.log
exec > /workspace/work/verify.log 2>&1
set -x
echo "=== MBR of SD image ==="
fdisk -l /workspace/output/xmio-sd-2g.img 2>/dev/null | tail -4
echo "=== idbloader magic @sector 64 ==="
dd if=/workspace/output/xmio-sd-2g.img bs=512 skip=64 count=2 2>/dev/null | od -A x -t x1z | head -2
echo "=== uboot magic @sector 16384 ==="
dd if=/workspace/output/xmio-sd-2g.img bs=512 skip=16384 count=2 2>/dev/null | od -A x -t x1z | head -2
echo "=== trust magic @sector 24576 ==="
dd if=/workspace/output/xmio-sd-2g.img bs=512 skip=24576 count=2 2>/dev/null | od -A x -t x1z | head -2
echo "=== SD partition mount test ==="
mkdir -p /mnt/sd
LOOP=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
echo "loopdev=$LOOP"
mount -o ro "$LOOP" /mnt/sd
ls /mnt/sd/boot/ | head -8
echo "=== SD armbianEnv.txt ==="
cat /mnt/sd/boot/armbianEnv.txt
umount /mnt/sd
losetup -d "$LOOP"
echo "=== SHA256 ==="
sha256sum /workspace/output/armbian_rootfs_26.2_xmio.img /workspace/output/xmio-sd-2g.img
echo "=== rootfs zImage vs deb zImage identity ==="
mkdir -p /mnt/nand /tmp/k
mount -o ro /workspace/output/armbian_rootfs_26.2_xmio.img /mnt/nand
dpkg-deb -x /workspace/work/kernel-out/final/linux-image-6.6.89-rk3128+_6.6.89-rk3128-2_armhf.deb /tmp/k
sha256sum /mnt/nand/boot/vmlinuz-6.6.89-rk3128+ /tmp/k/boot/vmlinuz-6.6.89-rk3128+ /mnt/nand/boot/dtb/rk3128-xmio.dtb /tmp/k/boot/dtb/rk3128-xmio.dtb
umount /mnt/nand
echo VERIFY_ALL_DONE
