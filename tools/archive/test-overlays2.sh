#!/usr/bin/env bash
exec > /workspace/work/fdtoverlay-verify.log 2>&1
set -e
rm -rf /tmp/ov && mkdir -p /tmp/ov && cd /tmp/ov
cp /workspace/output/dtb/rk3128-xmio.dtb base.dtb
OVL=/workspace/output/dtb/overlay
for o in uart1 uart2 usb-otg-host dmc-disabled wlan-esp8089 sdcard-enabled; do
  cp "$OVL/rk3128-$o.dtbo" .
done
fdtoverlay -i base.dtb -o merged-nand.dtb \
  rk3128-uart1.dtbo rk3128-uart2.dtbo rk3128-usb-otg-host.dtbo \
  rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo
fdtoverlay -i base.dtb -o merged-sd.dtb \
  rk3128-uart1.dtbo rk3128-usb-otg-host.dtbo \
  rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo rk3128-sdcard-enabled.dtbo
dtc -I dtb -O dts merged-nand.dtb 2>/dev/null > nand.dts
dtc -I dtb -O dts merged-sd.dtb 2>/dev/null > sd.dts
dtc -I dtb -O dts base.dtb 2>/dev/null > base.dts

echo "=== BASE uart2 (serial@20068000) ==="
grep -A6 'serial@20068000 {' base.dts | grep -E 'status|pinctrl' || echo '(no status line)'
echo "=== NAND merged uart2 ==="
grep -A8 'serial@20068000 {' nand.dts | grep -E 'status|pinctrl' || echo '(no status line)'
echo "=== SD merged uart2 (không apply uart2 overlay) ==="
grep -A8 'serial@20068000 {' sd.dts | grep -E 'status|pinctrl' || echo '(no status line)'
echo "=== BASE dmc ==="
grep -B1 -A2 'dmc' base.dts | grep -E '@|status' | head -6
echo "=== NAND merged dmc status ==="
grep -A4 'dmc {' nand.dts | head -6
echo "=== BASE sdmmc status ==="
grep -A6 'sdmmc@10218000 {' base.dts | grep status || echo '(none)'
echo "=== SD merged sdmmc status (boot.cmd force sdcard-enabled) ==="
grep -A10 'sdmmc@10218000 {' sd.dts | grep status || echo '(none)'
echo "=== NAND wlan-esp8089 effect ==="
grep -A4 'esp8089' nand.dts | head -8
echo "=== base vs merged uart2 diff check ==="
diff <(grep -A8 'serial@20068000 {' base.dts) <(grep -A8 'serial@20068000 {' nand.dts) && echo 'NO-DIFF (BUG?)' || echo 'UART2 CHANGED (expected)'
echo OVERLAY_VERIFY_DONE
