#!/usr/bin/env bash
# v24.3-prep2.sh — set_device_name error path + wifi module + DTS wifi node
set -uo pipefail

echo "=== 1. ledtrig-netdev set_device_name (221-265) — thi EU coi wlan0 ==="
sed -n '221,265p' /vol/kernel-src/drivers/leds/trigger/ledtrig-netdev.c

echo
echo "=== 2. module wifi trong rootfs v22 ==="
IMG=/workspace/output/armbian_rootfs_v22_xmio.img
debugfs -R "ls -l /lib/modules/6.6.89-rk3128+/kernel/drivers/net/wireless/rockchip_wlan" "$IMG" 2>/dev/null

echo
echo "=== 3. node wifi trong DTS v23 ==="
python3 - <<'EOF'
import re
d = open('/workspace/work/xmio-planb-v23.dts').read()
for kw in ['ssv', 'wireless-wlan', 'wifi', 'sdio']:
    for m in re.finditer(kw, d, re.I):
        s = d.rfind('\n', 0, m.start()-200)
        seg = d[max(0,m.start()-250):m.start()+400]
        if 'compatible' in seg or 'node' in kw:
            print(f'--- [{kw}] @ {m.start()} ---')
            print(seg[:600]); break
EOF

echo
echo "=== 4. debugfs co lenh symlink? ==="
debugfs -R "help" /workspace/output/armbian_rootfs_v22_xmio.img 2>/dev/null | grep -E 'symlink|sif' || echo "(check manual)"