#!/usr/bin/env bash
# v26-bootdir-check.sh — /boot trong rootfs v22 có gì và dùng được không
set -uo pipefail
IMG=/workspace/output/armbian_rootfs_v22_xmio.img
M=/mnt/rootfs-ro
mkdir -p "$M"
losetup -d /dev/loop2 2>/dev/null || true
losetup /dev/loop2 "$IMG" && mount -o ro /dev/loop2 "$M" || { echo "mount fail"; exit 1; }
echo "=== 1. /boot nội dung ==="
ls -la "$M/boot" 2>/dev/null
echo
echo "=== 2. dung lượng /boot ==="
du -sh "$M/boot" 2>/dev/null
du -ah "$M/boot" 2>/dev/null | sort -rh | head -15
echo
echo "=== 3. extlinux/armbianEnv (bootloader config đọc từ fs?) ==="
ls -la "$M/boot/extlinux" 2>/dev/null || echo "(không có extlinux/)"
cat "$M/boot/armbianEnv.txt" 2>/dev/null || echo "(không có armbianEnv.txt)"
echo
echo "=== 4. lib/modules (về cùng kernel) ==="
ls "$M/lib/modules" 2>/dev/null
echo
echo "=== 5. flash-kernel hook có cài không? ==="
ls "$M/usr/bin/flash-kernel" 2>/dev/null && echo "flash-kernel CÓ" || echo "flash-kernel không có"
ls "$M/etc/initramfs-tools/" 2>/dev/null | head -5
echo
echo "=== 6. file .deb kernel nào nằm trong rootfs ==="
ls "$M/root/"*.deb "$M/home/"*/*.deb 2>/dev/null | head -5 || echo "(none)"
umount "$M"; losetup -d /dev/loop2
echo DONE