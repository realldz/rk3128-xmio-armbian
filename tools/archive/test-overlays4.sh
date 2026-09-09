#!/usr/bin/env bash
exec > /workspace/work/fdtoverlay-verify4.log 2>&1
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
for f in base nand sd; do echo "=== $f dmc ==="; sed -n '/dmc {/,/^\t};/p' $f.dts | grep -E 'compatible|status'; done
echo DONE4
