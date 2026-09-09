#!/usr/bin/env bash
exec > /workspace/work/phandle-audit2.log 2>&1
set -x
dtc --version
cd /tmp
# stock DTB round-trip
dtc -I dtb -O dts /workspace/work/stock-dtbs/dtb_00000800.dtb > stock.dts 2>/dev/null
dtc -I dts -O dtb stock.dts -o stock2.dtb 2>&1 | grep -c "not a phandle reference" || true
# decompiled cru node in OUR base
awk '/clock-controller@20000000 \{/,/^\t\};/' base.dts | head -25
# where exactly does dtc point? first 3 warning lines with locations
dtc -I dts -O dtb base.dts -o base2.dtb 2>&1 | grep "not a phandle" | head -3
