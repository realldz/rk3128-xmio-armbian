#!/bin/sh
# check-rootfs-symlinks.sh — soi symlink usrmerge trong rootfs img
IMG=/workspace/output/armbian_rootfs_26.2_xmio.img
for p in /sbin /bin /lib /usr/sbin /usr/lib/systemd/systemd /usr/bin/sh /usr/lib/ld-linux-armhf.so.3 /usr/lib/arm-linux-gnueabihf; do
  echo "--- stat $p"
  debugfs -R "stat $p" "$IMG" 2>/dev/null | head -5
done
echo "=== ls /usr top ==="
debugfs -R "ls -l /usr" "$IMG" 2>/dev/null | head -12
