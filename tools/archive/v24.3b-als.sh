#!/usr/bin/env bash
# v24.3b-als.sh — mổ xẻ armbian-led-state trong rootfs v23
set -uo pipefail
IMG=/workspace/output/armbian_rootfs_v23_xmio.img

echo "=== 1. unit file co o dau ==="
debugfs -R "stat /usr/lib/systemd/system/armbian-led-state.service" "$IMG" 2>/dev/null | head -4
echo
echo "=== 2. unit content ==="
debugfs -R "cat /usr/lib/systemd/system/armbian-led-state.service" "$IMG" 2>/dev/null || echo MISSING
echo
echo "=== 3. script armbian-led-state ==="
for p in /usr/sbin/armbian-led-state /usr/bin/armbian-led-state /usr/lib/armbian-led-state/armbian-led-state; do
  debugfs -R "cat $p" "$IMG" 2>/dev/null | head -80 && break
done
echo
echo "=== 4. thu muc lien quan ==="
debugfs -R "ls -l /usr/lib/armbian-led-state" "$IMG" 2>/dev/null | head -10
debugfs -R "ls -l /var/lib/armbian-led-state" "$IMG" 2>/dev/null | head -10
echo
echo "=== 5. da enable chua (wants) ==="
debugfs -R "ls /etc/systemd/system/multi-user.target.wants" "$IMG" 2>/dev/null | grep -i led || echo "(chua enable)"
debugfs -R "ls /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null | grep -i led || echo "(sysinit: khong co)"