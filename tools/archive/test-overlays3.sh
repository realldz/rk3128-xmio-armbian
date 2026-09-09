#!/usr/bin/env bash
exec > /workspace/work/fdtoverlay-verify3.log 2>&1
set -e
rm -rf /tmp/ov && mkdir -p /tmp/ov && cd /tmp/ov
cp /workspace/output/dtb/rk3128-xmio.dtb base.dtb
OVL=/workspace/output/dtb/overlay
for o in uart1 uart2 usb-otg-host dmc-disabled wlan-esp8089 sdcard-enabled; do cp "$OVL/rk3128-$o.dtbo" .; done
fdtoverlay -i base.dtb -o merged-nand.dtb rk3128-uart1.dtbo rk3128-uart2.dtbo rk3128-usb-otg-host.dtbo rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo
fdtoverlay -i base.dtb -o merged-sd.dtb rk3128-uart1.dtbo rk3128-usb-otg-host.dtbo rk3128-dmc-disabled.dtbo rk3128-wlan-esp8089.dtbo rk3128-sdcard-enabled.dtbo
dtc -I dtb -O dts merged-nand.dtb 2>/dev/null > nand.dts
dtc -I dtb -O dts merged-sd.dtb 2>/dev/null > sd.dts
dtc -I dtb -O dts base.dtb 2>/dev/null > base.dts
P() { sed -n "/$2 {/,/^\t};/p" "$1" | head -18; }
echo "=== BASE uart2 ===";  P base.dts 'serial@20068000'
echo "=== NAND uart2 ===";  P nand.dts 'serial@20068000'
echo "=== SD uart2 ===";    P sd.dts  'serial@20068000'
echo "=== BASE dmc ===";    P base.dts '^	dmc '
echo "=== NAND dmc ===";    P nand.dts '^	dmc '
echo "=== BASE sdmmc ===";  P base.dts 'mmc@10214000'
echo "=== SD sdmmc ===";    P sd.dts  'mmc@10214000'
echo VERIFY3_DONE
