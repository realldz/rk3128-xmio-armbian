#!/usr/bin/env bash
# Add fallback baseline DTB into the XMIO rootfs image (for A/B testing via SSH).
exec > /workspace/work/add-dtb.log 2>&1
set -e
IMG=/workspace/output/armbian_rootfs_26.2_xmio.img
mkdir -p /mnt/nand
mount -o loop,rw "$IMG" /mnt/nand
cp /workspace/work/rk3128-linux.dtb /mnt/nand/boot/dtb/rk3128-linux.dtb
sync
umount /mnt/nand
e2fsck -fy "$IMG" | tail -2
echo "=== final /boot/dtb listing ==="
mount -o loop,ro "$IMG" /mnt/nand
ls -la /mnt/nand/boot/dtb/*.dtb
grep '^fdtfile' /mnt/nand/boot/armbianEnv.txt
umount /mnt/nand
echo FALLBACK_DTB_DONE
