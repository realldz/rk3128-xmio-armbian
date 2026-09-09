#!/usr/bin/env bash
exec > /workspace/work/round12-final.log 2>&1
set -e
cd /workspace/output
sha256sum armbian_rootfs_26.2_xmio.img xmio-sd-2g.img debs/*.deb dtb/rk3128-xmio.dtb dtb/rk3128-linux.dtb dtb/overlay/*.dtbo kernel/zImage nand-flash/* > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c OK
tar -czf XMIO-bundle.tar.gz debs dtb kernel nand-flash SHA256SUMS.txt ../docs/FLASH-GUIDE.md ../README.md ../NOTES.md ../tools/boot-patch 2>/dev/null
tar -tzf XMIO-bundle.tar.gz | wc -l
echo "=== UUID/label/fstab state ==="
mkdir -p /mnt/s /mnt/n
L=$(losetup --find --show --offset 16777216 /workspace/output/xmio-sd-2g.img)
tune2fs -l "$L" | grep -E 'UUID|volume name' || true
mount -o ro "$L" /mnt/s; grep UUID= /mnt/s/etc/fstab; umount /mnt/s; losetup -d "$L"
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
tune2fs -l "$L" | grep -E 'UUID|volume name' || true
mount -o ro "$L" /mnt/n; grep UUID= /mnt/n/etc/fstab; umount /mnt/n; losetup -d "$L"
echo ROUND12_FINAL_OK
