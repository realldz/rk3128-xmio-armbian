#!/usr/bin/env bash
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v15j_xmio.img
echo "=== basic.target.wants ==="
debugfs -R 'ls -p /etc/systemd/system/basic.target.wants' "$IMG" 2>/dev/null | tail -n +3 || true
echo "=== /etc/cron.d ==="
debugfs -R 'ls -p /etc/cron.d' "$IMG" 2>/dev/null | tail -n +3 || true
echo "=== /etc/cron.daily ==="
debugfs -R 'ls -p /etc/cron.daily' "$IMG" 2>/dev/null | tail -n +3 || true
echo "=== existing /etc/armbian-leds.conf? ==="
debugfs -R 'stat /etc/armbian-leds.conf' "$IMG" 2>/dev/null | head -2 || echo ABSENT
echo "=== /var/log/journal stat ==="
debugfs -R 'stat /var/log/journal' "$IMG" 2>/dev/null | head -3 || true
echo "=== wpa_supplicant (wifi capable?) ==="
debugfs -R 'stat /etc/wpa_supplicant' "$IMG" 2>/dev/null | head -2 || echo NO-WPA-DIR
