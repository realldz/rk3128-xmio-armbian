#!/usr/bin/env bash
# Embed xmio-collect diagnostic script into both images.
exec > /workspace/work/embed-collect.log 2>&1
set -e
mkdir -p /mnt/nand /mnt/sd
cp /workspace/tools/xmio-collect.sh /tmp/xmio-collect
chmod +x /tmp/xmio-collect

echo "=== NAND rootfs ==="
mount -o loop,rw /workspace/output/armbian_rootfs_26.2_xmio.img /mnt/nand
install -m 0755 /tmp/xmio-collect /mnt/nand/usr/local/bin/xmio-collect
sync; umount /mnt/nand

echo "=== SD image ==="
LOOP=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o rw "$LOOP" /mnt/sd
install -m 0755 /tmp/xmio-collect /mnt/sd/usr/local/bin/xmio-collect
sync; umount /mnt/sd; losetup -d "$LOOP"

echo "=== verify ==="
mount -o loop,ro /workspace/output/armbian_rootfs_26.2_xmio.img /mnt/nand
ls -la /mnt/nand/usr/local/bin/xmio-collect; umount /mnt/nand
LOOP=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
mount -o ro "$LOOP" /mnt/sd
ls -la /mnt/sd/usr/local/bin/xmio-collect; umount /mnt/sd; losetup -d "$LOOP"
echo EMBED_DONE
