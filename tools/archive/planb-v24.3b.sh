#!/usr/bin/env bash
# planb-v24.3b.sh — rootfs v23: dùng CHỈ armbian-led-state
#  - gỡ xmio-led-green (script + unit + symlink sysinit)
#  - enable armbian-led-state.service (WantedBy=basic.target)
#  - gieo /etc/armbian-leds.conf: xanh none+on, vàng netdev wlan0
# Kernel/DTB KHÔNG đổi (boot/resource v24.3 giữ nguyên — DTB chỉ quyết
# định trạng thái mặc định "xanh sáng từ ~2s" trước khi restore chạy).
set -euo pipefail
IMG=/workspace/output/armbian_rootfs_v23_xmio.img
W=/workspace/work

echo "=== 1. conf mong muon ==="
mkdir -p "$W/ledrootfs/etc"
cat > "$W/ledrootfs/etc/armbian-leds.conf" <<'EOF'
# XMIO: green = solid on, yellow = netdev wlan0 (link + traffic)
# maintained by armbian-led-state (save at shutdown, restore at boot)
[/sys/class/leds/xmio:red-green:status]
trigger=none
brightness=1

[/sys/class/leds/xmio:yellow:io]
trigger=netdev
device_name=wlan0
link=1
rx=1
tx=1

EOF
chmod 644 "$W/ledrootfs/etc/armbian-leds.conf"
cat "$W/ledrootfs/etc/armbian-leds.conf"

echo "=== 2. debugfs: gỡ xmio-led-green ==="
debugfs -w -R "rm /etc/systemd/system/sysinit.target.wants/xmio-led-green.service" "$IMG" 2>&1 | grep -v '^debugfs' || true
debugfs -w -R "rm /etc/systemd/system/xmio-led-green.service" "$IMG" 2>&1 | grep -v '^debugfs' || true
debugfs -w -R "rm /usr/local/sbin/xmio-led-green" "$IMG" 2>&1 | grep -v '^debugfs' || true

echo "=== 3. debugfs: enable armbian-led-state (basic.target.wants) ==="
debugfs -w -R "mkdir /etc/systemd/system/basic.target.wants" "$IMG" 2>/dev/null || true
debugfs -w -R "symlink /etc/systemd/system/basic.target.wants/armbian-led-state.service /usr/lib/systemd/system/armbian-led-state.service" "$IMG"

echo "=== 4. debugfs: gieo conf ==="
debugfs -w -R "write $W/ledrootfs/etc/armbian-leds.conf /etc/armbian-leds.conf" "$IMG"
sync; sleep 2

echo "=== 5. verify ==="
echo "--- xmio-led-green phai bien mat ---"
debugfs -R "stat /usr/local/sbin/xmio-led-green" "$IMG" 2>&1 | head -1
debugfs -R "stat /etc/systemd/system/xmio-led-green.service" "$IMG" 2>&1 | head -1
debugfs -R "ls /etc/systemd/system/sysinit.target.wants" "$IMG" 2>/dev/null | grep -c xmio || echo "sysinit.wants: khong con xmio"
echo "--- armbian-led-state enabled ---"
debugfs -R "stat /etc/systemd/system/basic.target.wants/armbian-led-state.service" "$IMG" 2>&1 | grep -E 'Inode|Type|Mode' | head -3
echo "--- conf trong rootfs ---"
debugfs -R "cat /etc/armbian-leds.conf" "$IMG"
echo "--- unit van nguyen ---"
debugfs -R "stat /usr/lib/systemd/system/armbian-led-state.service" "$IMG" | grep Mode

echo "=== 6. hashes + bundle ==="
cd /workspace/output && rm -f SHA256SUMS.txt
sha256sum armbian_rootfs_v23_xmio.img > SHA256SUMS.txt
cd /workspace/output/planb-stock-uboot && rm -f SHA256SUMS.txt && sha256sum \
  parameter.txt parameter.txt.native misc.img baseparamer-720P.img \
  uboot-stock.img resource.img boot.img rk3128-xmio-planb.dtb \
  initrd.img.gz "rk3128MiniLoaderAll(L)_V2.25_ink.bin" \
  onbox/vendor-mac onbox/xmio-led-arm onbox/xmio-led.service > SHA256SUMS.txt
sha256sum -c SHA256SUMS.txt | grep -c ': OK'
bash /workspace/tools/bundle.sh
tail -1 /workspace/work/bundle.log
md5sum /workspace/output/armbian_rootfs_v23_xmio.img
echo PLANB_V243B_DONE