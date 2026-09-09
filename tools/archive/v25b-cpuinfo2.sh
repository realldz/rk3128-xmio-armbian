#!/usr/bin/env bash
# v25b-cpuinfo2.sh — dt_compat machine + serial-number DT + soc0
set -uo pipefail
cd /vol/kernel-src

echo "=== 1. ROCKCHIP_DT dt_compat list (vi sao khong match rk3128?) ==="
sed -n '40,90p' arch/arm/mach-rockchip/rockchip.c

echo
echo "=== 2. Serial line: doc 'serial-number' tu DT? ==="
grep -n 'serial-number\|system_serial' arch/arm/kernel/devtree.c arch/arm/kernel/setup.c | head -15

echo
echo "=== 3. /sys/devices/soc0 cho rockchip arm32? ==="
grep -rn 'soc_device_register\|soc_id' drivers/soc/rockchip/ 2>/dev/null | head -5 || echo "(khong co)"
ls drivers/soc/rockchip/ 2>/dev/null

echo
echo "=== 4. c_show 'model name' nguon %s (cpu_name) ==="
sed -n '1320,1330p' arch/arm/kernel/setup.c
