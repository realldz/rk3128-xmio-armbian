#!/usr/bin/env bash
set -uo pipefail
D=/workspace/work/xmio-planb-v23.dts
echo "=== node with PCLK_EFUSE (around line 1620-1660) ==="
sed -n '1620,1660p' "$D"
echo "=== any efuse node ==="
grep -n -B2 -A10 'efuse' "$D" | head -40
echo "=== compiled DTB: is efuse node present? ==="
dtc -I dtb -O dts /workspace/output/planb-stock-uboot/rk3128-xmio-planb.dtb 2>/dev/null | grep -n -B2 -A12 'efuse' | head -40
