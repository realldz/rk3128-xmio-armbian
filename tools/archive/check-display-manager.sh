#!/bin/sh
# check-display-manager.sh — lightdm state trong v23.2 + uuid check 26.2
IMG2=/workspace/output/armbian_rootfs_v23.2_xmio.img
echo "=== v23.2 /etc/systemd/system/display-manager.service ==="
debugfs -R "stat /etc/systemd/system/display-manager.service" "$IMG2" 2>&1 | grep -E 'Inode|Type|Fast link|No such' | head -4
echo "=== v23.2 /etc/X11/xorg.conf.d (có 60-tearfree không) ==="
debugfs -R "ls -l /etc/X11/xorg.conf.d" "$IMG2" 2>&1 | head -8
echo "=== uuid 26.2 (so với f62d9d2c trong panic log) ==="
dumpe2fs -h /workspace/output/armbian_rootfs_26.2_xmio.img 2>/dev/null | grep -E 'UUID|Block count|Free blocks'
echo "=== uuid v23.2 ==="
dumpe2fs -h "$IMG2" 2>/dev/null | grep -E 'UUID|Block count|Free blocks'
