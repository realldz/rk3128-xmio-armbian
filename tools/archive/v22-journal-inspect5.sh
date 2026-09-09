#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== sysinit.target.wants (ramlog enabled?) ==="
debugfs -R 'ls -p /etc/systemd/system/sysinit.target.wants' "$IMG" 2>/dev/null | tail -n +3 || true
echo "=== /var/log.hdd stat (exists?) ==="
debugfs -R 'stat /var/log.hdd' "$IMG" 2>&1 | head -4 || true
echo "=== armbian-ramlog script lines 80-170 (start function) ==="
debugfs -R 'cat /usr/lib/armbian/armbian-ramlog' "$IMG" 2>/dev/null | sed -n '80,170p'
echo "=== /etc/fstab ==="
debugfs -R 'cat /etc/fstab' "$IMG" 2>/dev/null | grep -vE '^#|^$' || echo EMPTY
