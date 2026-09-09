#!/usr/bin/env bash
# v24.3-prep.sh — 3 kiểm tra trước khi cấu hình LED
set -uo pipefail

echo "=== 1. leds node trong DTS v23 (status-led + yellow) ==="
python3 - <<'EOF'
d = open('/workspace/work/xmio-planb-v23.dts').read()
i = d.find('gpio-leds')
print(d[i-20:i+1200] if i >= 0 else 'NO gpio-leds node!')
EOF

echo
echo "=== 2. ledtrig-netdev 6.6: device_name co can device ton tai? ==="
F=/vol/kernel-src/drivers/leds/trigger/ledtrig-netdev.c
grep -n 'dev_get_by_name\|device_name\|-ENODEV\|list_for_each' "$F" | head -15
echo "--- netdev_trig_set_device ---"
sed -n '/static ssize_t netdev_trig_set_device/,/^}/p' "$F" | head -30 || \
  grep -n 'device_name_store' "$F"

echo
echo "=== 3. rootfs v22: armbian-led-state enabled? NM dispatcher dir? ==="
IMG=/workspace/output/armbian_rootfs_v22_xmio.img
debugfs -R "stat /etc/systemd/system/multi-user.target.wants/armbian-led-state.service" "$IMG" 2>/dev/null | head -3
echo "--- dispatcher dir ---"
debugfs -R "ls -l /etc/NetworkManager/dispatcher.d" "$IMG" 2>/dev/null | head -12
echo "--- net driver ssv6051 co trong rootfs? ---"
debugfs -R "ls /lib/modules/6.6.89-rk3128+/kernel/drivers/net/wireless" "$IMG" 2>/dev/null | head -8