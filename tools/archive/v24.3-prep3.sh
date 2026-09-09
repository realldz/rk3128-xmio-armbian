#!/usr/bin/env bash
# v24.3-prep3.sh — notifier bind-later? esp8089 module? sdio host node?
set -uo pipefail
F=/vol/kernel-src/drivers/leds/trigger/ledtrig-netdev.c

echo "=== 1. netdev_trig_notify: NETDEV_REGISTER co bind theo ten? ==="
sed -n '/static int netdev_trig_notify/,/^}/p' "$F"

echo
echo "=== 2. wifi kernel config ==="
grep -E 'ESP8089|SSV6|SSV6051|RTL8189|WLAN_ROCKCHIP' /vol/kernel-build/.config

echo
echo "=== 3. module esp8089/ssv trong rootfs ==="
IMG=/workspace/output/armbian_rootfs_v22_xmio.img
for sub in rkwifi rtl8189es rtl8189fs ssv6xxx; do
  echo "--- $sub ---"
  debugfs -R "ls /lib/modules/6.6.89-rk3128+/kernel/drivers/net/wireless/rockchip_wlan/$sub" "$IMG" 2>/dev/null | head -6
done

echo
echo "=== 4. node co phandle 0x92 (wifi_sdio_host) ==="
python3 - <<'EOF'
import re
d = open('/workspace/work/xmio-planb-v23.dts').read()
i = d.find('phandle = <0x92>;')
if i < 0:
    print('khong thay 0x92'); raise SystemExit
s = d.rfind('\n\t', 0, i)
print(d[s-250:i+60])
EOF