#!/usr/bin/env bash
# find-v15-holder.sh — ai đang giữ file v15?
echo "=== loop devices ==="
losetup -a 2>/dev/null || true
echo
echo "=== mounts liên quan ==="
grep -Ei 'v15|loop' /proc/mounts || echo "(none)"
echo
echo "=== open fds trỏ tới v15 ==="
found=0
for p in /proc/[0-9]*/fd/*; do
  link=$(readlink "$p" 2>/dev/null) || continue
  case "$link" in
    *v15*) echo "PID ${p} -> $link"; found=1 ;;
  esac
done
[ "$found" = 0 ] && echo "(no fd holds v15 inside container)"
echo
echo "=== fileStill deletable? ==="
rm -f /workspace/output/armbian_rootfs_v15_xmio.img && echo DELETED || echo STILL-LOCKED
ls -la /workspace/output/armbian_rootfs_v15_xmio.img 2>/dev/null || echo "(gone)"
