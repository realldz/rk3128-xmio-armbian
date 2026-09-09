#!/bin/sh
# check-init-chain.sh — trace symlink chain sbin/init -> systemd
IMG=/workspace/output/armbian_rootfs_26.2_xmio.img
for p in /sbin /bin /sbin/init /bin/init /lib/systemd/systemd /usr/lib/systemd/systemd /bin/sh /usr/bin/sh; do
  echo "=== stat $p"
  debugfs -R "stat $p" "$IMG" 2>/dev/null | grep -E 'Inode|Type|Size|Fast link|BLOCKS' | head -6
done
echo "=== ls /sbin (real dir content via symlink? dump raw) ==="
debugfs -R "ls -l /usr/sbin" "$IMG" 2>/dev/null | grep -E ' init| reboot| shutdown| udevadm' 
echo "=== ls /lib/systemd ==="
debugfs -R "ls -l /lib/systemd" "$IMG" 2>/dev/null | head -8
echo "=== ls /usr/lib/systemd ==="
debugfs -R "ls -l /usr/lib/systemd" "$IMG" 2>/dev/null | head -8
echo "=== compare 23.2 rootfs ==="
IMG2=/workspace/output/armbian_rootfs_v23.2_xmio.img
for p in /sbin /sbin/init /lib/systemd/systemd /bin/sh; do
  echo "--- 23.2 stat $p"
  debugfs -R "stat $p" "$IMG2" 2>/dev/null | grep -E 'Inode|Type|Size|Fast link' | head -4
done
