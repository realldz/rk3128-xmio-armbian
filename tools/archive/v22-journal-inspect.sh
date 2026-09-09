#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== md5 v15j ==="
md5sum "$IMG" | cut -c1-32
echo "=== /etc/systemd/journald.conf (active lines) ==="
debugfs -R 'cat /etc/systemd/journald.conf' "$IMG" 2>/dev/null | grep -vE '^#|^$' || echo EMPTY
echo "=== /etc/systemd/journald.conf.d/ ==="
debugfs -R 'ls -p /etc/systemd/journald.conf.d' "$IMG" 2>/dev/null | tail -n +3 || echo NO-DIR
echo "=== /var/log/journal ==="
debugfs -R 'ls -p /var/log/journal' "$IMG" 2>/dev/null | tail -n +3 || echo NO-DIR
echo "=== /var/log ==="
debugfs -R 'ls -p /var/log' "$IMG" 2>/dev/null | tail -n +3 | head -15
echo "=== multi-user.target.wants (services writing logs?) ==="
debugfs -R 'ls -p /etc/systemd/system/multi-user.target.wants' "$IMG" 2>/dev/null | tail -n +3
echo "=== log2ram present? ==="
debugfs -R 'stat /usr/local/sbin/log2ram' "$IMG" 2>/dev/null | head -2 || echo NO-LOG2RAM
echo "=== rsyslog config present? ==="
debugfs -R 'stat /etc/rsyslog.conf' "$IMG" 2>/dev/null | head -2 || echo NO-RSYSLOG-CONF
echo "=== systemd version in image ==="
debugfs -R 'cat /usr/lib/systemd/systemd' "$IMG" 2>/dev/null | strings 2>/dev/null | head -1 || true
