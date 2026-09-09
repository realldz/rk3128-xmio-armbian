#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== fake-hwclock units present? ==="
debugfs -R 'stat /lib/systemd/system/fake-hwclock-save.timer' "$IMG" 2>/dev/null | head -2 || echo NO-TIMER-UNIT
debugfs -R 'ls -p /lib/systemd/system/timers.target.wants' "$IMG" 2>/dev/null | tail -n +3 || true
echo "=== chrony.conf driftfile ==="
debugfs -R 'cat /etc/chrony/chrony.conf' "$IMG" 2>/dev/null | grep -E '^driftfile' || echo NO-DRIFT-LINE
echo "=== /var/lib/chrony stat ==="
debugfs -R 'stat /var/lib/chrony' "$IMG" 2>/dev/null | head -3 || echo ABSENT
