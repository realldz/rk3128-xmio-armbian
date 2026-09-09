#!/usr/bin/env bash
exec > /workspace/work/add-dtb-sd.log 2>&1
set -e
IMG=/workspace/output/xmio-sd-2g.img
mkdir -p /mnt/sd
LOOP=$(losetup --find --show --offset 16777216 "$IMG")
mount -o rw "$LOOP" /mnt/sd
cp /workspace/work/rk3128-linux.dtb /mnt/sd/boot/dtb/rk3128-linux.dtb
sync
umount /mnt/sd
losetup -d "$LOOP"
e2fsck -fy "$IMG" | tail -2
echo "=== regenerate SHA256SUMS ==="
cd /workspace/output
sha256sum armbian_rootfs_26.2_xmio.img xmio-sd-2g.img debs/*.deb dtb/rk3128-xmio.dtb dtb/overlay/*.dtbo kernel/zImage nand-flash/* > SHA256SUMS.txt
cat SHA256SUMS.txt
echo SD_FALLBACK_DONE
