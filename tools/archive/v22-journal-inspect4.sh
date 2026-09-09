#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== armbian-ramlog.service ==="
debugfs -R 'cat /usr/lib/systemd/system/armbian-ramlog.service' "$IMG" 2>/dev/null || echo ABSENT
echo "=== /etc/default/armbian-ramlog ==="
debugfs -R 'cat /etc/default/armbian-ramlog' "$IMG" 2>/dev/null || echo ABSENT
echo "=== armbian-ramlog script (first 80 lines) ==="
debugfs -R 'cat /usr/lib/armbian/armbian-ramlog' "$IMG" 2>/dev/null | head -80 || echo ABSENT
echo "=== armbian-truncate-logs script ==="
debugfs -R 'cat /usr/lib/armbian/armbian-truncate-logs' "$IMG" 2>/dev/null || echo ABSENT
echo "=== /var/log.hdd present? ==="
debugfs -R 'ls -p /var/log.hdd' "$IMG" 2>/dev/null | tail -n +3 | head -8 || echo NO-HDD
echo "=== armbian-ramlog in basic/sysinit wants? ==="
debugfs -R 'ls -p /etc/systemd/system/local-fs.target.wants' "$IMG" 2>/dev/null | tail -n +3 || true
