#!/bin/sh
# check-v232-full.sh — verify v23.2 init chain + which rootfs is live lineage
IMG2=/workspace/output/armbian_rootfs_v23.2_xmio.img
echo "=== v23.2 stat /lib (stderr visible) ==="
debugfs -R "stat /lib" "$IMG2" 2>&1 | head -10
echo "=== v23.2 stat /lib/systemd/systemd (stderr visible) ==="
debugfs -R "stat /lib/systemd/systemd" "$IMG2" 2>&1 | head -10
echo "=== v23.2 stat /usr/lib/systemd/systemd ==="
debugfs -R "stat /usr/lib/systemd/systemd" "$IMG2" 2>&1 | grep -E 'Inode|Type|Size' | head -3
echo "=== v23.2 stat /sbin/init ==="
debugfs -R "stat /sbin/init" "$IMG2" 2>&1 | grep -E 'Inode|Type|Fast|Size' | head -4
echo "=== v23.2 ls /lib (follow) ==="
debugfs -R "ls -l /lib/" "$IMG2" 2>&1 | head -14
echo "=== md5 all rootfs candidates ==="
md5sum /workspace/output/armbian_rootfs_*.img
