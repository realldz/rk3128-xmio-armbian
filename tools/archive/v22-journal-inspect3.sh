#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== armbian-hardware-monitor.service ==="
debugfs -R 'cat /usr/lib/systemd/system/armbian-hardware-monitor.service' "$IMG" 2>/dev/null || echo ABSENT
echo "=== armbian-hardware-monitor script (head) ==="
debugfs -R 'cat /usr/lib/armbian/armbian-hardware-monitor' "$IMG" 2>/dev/null | head -40 || echo ABSENT
echo "=== armbian-ram-logging (cron.daily) ==="
debugfs -R 'cat /etc/cron.daily/armbian-ram-logging' "$IMG" 2>/dev/null || echo ABSENT
echo "=== armbian-truncate-logs (cron.d) ==="
debugfs -R 'cat /etc/cron.d/armbian-truncate-logs' "$IMG" 2>/dev/null || echo ABSENT
echo "=== logrotate.conf head ==="
debugfs -R 'cat /etc/logrotate.conf' "$IMG" 2>/dev/null | head -15 || echo ABSENT
