#!/usr/bin/env bash
# Simulate exactly what U-Boot does at boot: apply the armbianEnv overlay sets
# onto rk3128-xmio.dtb with fdtoverlay, then inspect the merged result.
exec > /workspace/work/fdtoverlay-test.log 2>&1
set -e
rm -rf /tmp/ov && mkdir -p /tmp/ov && cd /tmp/ov
cp /workspace/output/dtb/rk3128-xmio.dtb base.dtb
OVL=/workspace/output/dtb/overlay
for o in uart1 uart2 usb-otg-host dmc-disabled wlan-esp8089 sdcard-enabled; do
  cp "$OVL/rk3128-$o.dtbo" .
done
which fdtoverlay

echo "=== NAND overlay set: uart1 uart2 usb-otg-host dmc-disabled wlan-esp8089 ==="
fdtoverlay -i base.dtb -o merged-nand.dtb \
  rk3128-uart1.dtbo rk3128-uart2.dtbo rk3128-usb-otg-host.dtbo \
  rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo
echo "apply-exit=$?"

echo "=== SD overlay set (boot.cmd forces sdcard-enabled, drops uart2) ==="
fdtoverlay -i base.dtb -o merged-sd.dtb \
  rk3128-uart1.dtbo rk3128-usb-otg-host.dtbo \
  rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo rk3128-sdcard-enabled.dtbo
echo "apply-exit=$?"

for f in merged-nand.dtb merged-sd.dtb; do
  echo "=== inspect $f ==="
  dtc -I dtb -O dts "$f" 2>/dev/null > "$f.dts"
  echo "-- uart2:";    grep -A3 'uart2@20068000' "$f.dts" | head -6
  echo "-- esp8089:";  grep -c 'esp8089' "$f.dts"
  echo "-- hog:";      grep -A4 'vcc-host-vbus-hog' "$f.dts" | head -6
  echo "-- dmc:";      grep -B1 -A2 'dmc@' "$f.dts" | head -8
  echo "-- sdmmc:";    grep -A2 'sdmmc@' "$f.dts" | head -6
done
echo OVERLAY_TEST_DONE
