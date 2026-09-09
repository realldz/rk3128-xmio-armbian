#!/usr/bin/env bash
# v24.3-rootfs-files.sh — sinh 2 file LED cho rootfs v23
# (script + service; enable sẽ làm bằng debugfs symlink)
set -euo pipefail
D=/workspace/work/ledrootfs
rm -rf "$D"; mkdir -p "$D/etc/systemd/system" "$D/usr/local/sbin"

cat > "$D/usr/local/sbin/xmio-led-green" <<'EOF'
#!/bin/sh
# XMIO LED: xanh = default-on (enforce), vàng = netdev wlan0 (arm-once,
# trigger tự bind khi wlan0 register qua NETDEV_REGISTER notifier).
S=/sys/class/leds/xmio:red-green:status
Y=/sys/class/leds/xmio:yellow:io
# xanh: bỏ mọi trigger, bật sáng
[ -d "$S" ] && { echo none > "$S/trigger" 2>/dev/null; echo 1 > "$S/brightness"; }
# vàng: arm netdev wlan0 (chấp nhận cả khi wlan0 chưa tồn tại)
if [ -d "$Y" ]; then
  echo netdev > "$Y/trigger" 2>/dev/null
  echo wlan0  > "$Y/device_name" 2>/dev/null
  echo 1 > "$Y/link" 2>/dev/null      # sáng khi link up
  echo 1 > "$Y/rx" 2>/dev/null        # + nháy theo traffic
  echo 1 > "$Y/tx" 2>/dev/null
fi
exit 0
EOF
chmod +x "$D/usr/local/sbin/xmio-led-green"

cat > "$D/etc/systemd/system/xmio-led-green.service" <<'EOF'
[Unit]
Description=XMIO LED: green default-on, yellow netdev wlan0
DefaultDependencies=no
After=systemd-modules-load.service
Before=sysinit.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/xmio-led-green
RemainAfterExit=yes

[Install]
WantedBy=sysinit.target
EOF

echo "files generated:"
ls -la "$D/usr/local/sbin" "$D/etc/systemd/system"
cat "$D/usr/local/sbin/xmio-led-green"