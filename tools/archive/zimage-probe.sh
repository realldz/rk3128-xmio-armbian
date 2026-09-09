#!/usr/bin/env bash
exec > /workspace/work/zimage-rknand.log 2>&1
set -e
mkdir -p /mnt/n
L=$(losetup --find --show /workspace/output/armbian_rootfs_26.2_xmio.img)
mount -o ro "$L" /mnt/n
Z=/mnt/n/boot/zImage
echo "=== rknand strings in zImage ==="
strings -a "$Z" | grep -i 'rknand' | sort -u | head -20
echo "=== rknand_root exact? ==="
strings -a "$Z" | grep -c 'rknand_root' || true
echo "=== builtin modinfo entries (nand) ==="
zgrep -a 'nand' /mnt/n/boot/uInitrd-6.6.89-rk3128+ 2>/dev/null | head -5
tail -c +65 /mnt/n/boot/uInitrd-6.6.89-rk3128+ | zcat 2>/dev/null | grep -a 'rknand' | strings | head -10
echo "=== rkflash / sftl strings ==="
strings -a "$Z" | grep -iE 'rkflash|rknand0|rk_sftl' | sort -u | head -15
umount /mnt/n; losetup -d "$L"
echo ZIMAGE_PROBE_DONE
