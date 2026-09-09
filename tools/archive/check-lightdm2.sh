#!/bin/sh
# check-lightdm2.sh — lightdm enable mechanism trong v23.2
IMG2=/workspace/output/armbian_rootfs_v23.2_xmio.img
echo "=== stat display-manager.service (raw) ==="
debugfs -R "stat /etc/systemd/system/display-manager.service" "$IMG2" 2>&1
echo "=== ls /etc/systemd/system ==="
debugfs -R "ls -l /etc/systemd/system" "$IMG2" 2>&1 | head -25
echo "=== ls graphical.target.wants ==="
debugfs -R "ls -l /etc/systemd/system/graphical.target.wants" "$IMG2" 2>&1 | head -12
echo "=== stat /sbin/init chain sanity (follow to systemd) ==="
debugfs -R "stat /lib/systemd/systemd" "$IMG2" 2>&1 | grep -E 'Inode|Type|Size' | head -3
