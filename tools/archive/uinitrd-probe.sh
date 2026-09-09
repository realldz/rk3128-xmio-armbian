#!/usr/bin/env bash
exec > /workspace/work/uinitrd-probe.log 2>&1
set -e
mkdir -p /mnt/n /tmp/uird
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
echo "=== uInitrd header ==="
file /mnt/n/boot/uInitrd-6.6.89-rk3128+
cd /tmp/uird && rm -rf *
# uInitrd = uImage-wrapped cpio; skip 64-byte header
tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ | (zcat 2>/dev/null || cpio -idmv --no-absolute-filenames) > /dev/null 2>&1 || true
# try proper unpack: cpio from zcat
ls /tmp/uird | head -5
echo "=== retry with explicit steps ==="
rm -rf /tmp/uird/*; cd /tmp/uird
tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ > data.gz
file data.gz
zcat data.gz > data.cpio 2>/dev/null || (echo zcat-failed; cp data.gz data.cpio)
file data.cpio
cpio -idm --no-absolute-filenames < data.cpio 2>&1 | tail -3
echo "=== rknand references in initramfs ==="
grep -rln "rknand" . 2>/dev/null | head -10
echo "=== local-top / custom scripts ==="
ls scripts/local-top/ 2>/dev/null; ls conf/ 2>/dev/null | head
echo "=== cmdline expectations ==="
grep -rn "rknand_root" conf/ scripts/ 2>/dev/null | head -10
echo "=== rootfs udev rules mentioning rknand ==="
grep -rln "rknand" /mnt/n/etc/udev /mnt/n/lib/udev 2>/dev/null | head -10
echo "=== rootfs modules files for rkflash/rknand ==="
find /mnt/n/lib/modules/6.6.89-rk3128+ -iname '*nand*' 2>/dev/null | head -10
umount /mnt/n; losetup -d "$L"
echo UINITRD_PROBE_DONE
