#!/bin/sh
# check-lib-dirs.sh — compare /lib between 26.2 (broken) and 23.2 (boots fine)
IMG=/workspace/output/armbian_rootfs_26.2_xmio.img
IMG2=/workspace/output/armbian_rootfs_v23.2_xmio.img
echo "########## 26.2 ##########"
echo "=== ls -l /lib ==="
debugfs -R "ls -l /lib" "$IMG" 2>/dev/null | head -20
echo "=== ls -l /usr/lib | head ==="
debugfs -R "ls -l /usr/lib" "$IMG" 2>/dev/null | head -20
echo "=== stat /usr/lib/modules (26.2) ==="
debugfs -R "stat /usr/lib/modules" "$IMG" 2>/dev/null | grep -E 'Inode|Type' | head -2
echo "=== stat /lib/modules (26.2) ==="
debugfs -R "stat /lib/modules" "$IMG" 2>/dev/null | grep -E 'Inode|Type' | head -2
echo "########## 23.2 ##########"
echo "=== stat /lib (full) ==="
debugfs -R "stat /lib" "$IMG2" 2>/dev/null | head -8
echo "=== ls -l /lib | head ==="
debugfs -R "ls -l /lib" "$IMG2" 2>/dev/null | head -8
echo "=== stat /usr/lib/modules (23.2) ==="
debugfs -R "stat /usr/lib/modules" "$IMG2" 2>/dev/null | grep -E 'Inode|Type' | head -2
