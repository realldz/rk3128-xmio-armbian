#!/usr/bin/env bash
exec > /workspace/work/phandle-audit.log 2>&1
set -x
cd /tmp
dtc -I dtb -O dts /workspace/output/dtb/rk3128-xmio.dtb > base.dts 2>/dev/null
echo "=== base recompile warnings ==="
dtc -I dts -O dtb base.dts -o base2.dtb 2>&1 | grep -c "not a phandle reference" || true
echo "=== merged recompile warnings ==="
fdtoverlay -i /workspace/output/dtb/rk3128-xmio.dtb -o merged.dtb \
  /workspace/output/dtb/overlay/rk3128-uart1.dtbo \
  /workspace/output/dtb/overlay/rk3128-uart2.dtbo \
  /workspace/output/dtb/overlay/rk3128-usb-otg-host.dtbo \
  /workspace/output/dtb/overlay/rk3128-dmc-disabled.dtbo \
  /workspace/output/dtb/overlay/rk3128-wlan-esp8089.dtbo
dtc -I dtb -O dts merged.dtb > merged.dts 2>/dev/null
dtc -I dts -O dtb merged.dts -o merged2.dtb 2>&1 | grep -c "not a phandle reference" || true
echo "=== sample: cpu@f00 clocks in base.dts ==="
grep -n -A8 "cpu@f00" base.dts | head -14
echo "=== cru node phandle ==="
grep -n -B2 -A2 "clock-controller@20000000" base.dts | head -8
echo "=== cpu0 phandle ==="
grep -n "cpu@f00 {" base.dts | head -2
awk '/cpu@f00 \{/,/\};/' base.dts | grep -n "phandle"
echo "=== check phandle 0x06 target in base.dts ==="
grep -n "phandle = <0x06>" base.dts | head -3
echo "=== serial@20064000 full node ==="
awk '/serial@20064000 \{/,/\t\};/' base.dts | head -20
