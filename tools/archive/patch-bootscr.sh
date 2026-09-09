#!/usr/bin/env bash
# Install XMIO boot.cmd/boot.scr (with xmio_fdt_override hooks) into both images.
exec > /workspace/work/patch-bootscr.log 2>&1
set -e
mkdir -p /mnt/n /mnt/s

echo "=== NAND rootfs ==="
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o rw $L /mnt/n
cp /workspace/tools/boot-patch/boot.cmd  /mnt/n/boot/boot.cmd
cp /workspace/tools/boot-patch/boot.scr  /mnt/n/boot/boot.scr
sync; umount /mnt/n; losetup -d $L

echo "=== SD image ==="
L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o rw $L /mnt/s
cp /workspace/tools/boot-patch/boot.cmd  /mnt/s/boot/boot.cmd
cp /workspace/tools/boot-patch/boot.scr  /mnt/s/boot/boot.scr
sync; umount /mnt/s; losetup -d $L

echo "=== verify ==="
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro $L /mnt/n
tail -c +65 /mnt/n/boot/boot.scr | grep -c xmio_fdt_override
ls -la /mnt/n/boot/boot.scr /mnt/n/boot/boot.cmd
umount /mnt/n; losetup -d $L
echo PATCH_BOOTSCR_DONE
