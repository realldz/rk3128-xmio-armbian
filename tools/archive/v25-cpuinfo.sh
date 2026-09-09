#!/usr/bin/env bash
# v25-cpuinfo.sh — vì sao /proc/cpuinfo không hiện tên RK3128?
set -uo pipefail
cd /vol/kernel-src

echo "=== 1. rockchip_cpuinfo.c — initcall bi blacklist trong cmdline ==="
F=arch/arm/mach-rockchip/rockchip_cpuinfo.c
if [ -f "$F" ]; then
  grep -n "arch_initcall\|system_serial\|soc_rev\|chip_id\|efuse" "$F" | head -20
  echo "--- body ngắn ---"
  sed -n '/static int __init rockchip_cpuinfo_init/,/^}/p' "$F"
else
  echo "khong co rockchip_cpuinfo.c"
fi

echo
echo "=== 2. 'model name' tren ARM32 den tu dau ==="
grep -n '"model name' arch/arm/kernel/setup.c
grep -n 'cpu_name' arch/arm/mm/proc-v7.S | head -5
grep -n -A3 'cpu_p015\|cortex-a7' arch/arm/mm/proc-v7.S | grep -i 'ARMv7\|string' | head -5

echo
echo "=== 3. 'Hardware:' line + machine_desc ==="
grep -n '"Hardware' arch/arm/kernel/setup.c
grep -n 'DT_MACHINE_START\|MACHINE_START' arch/arm/mach-rockchip/rockchip.c 2>/dev/null
grep -rn '"Generic DT based system"' arch/arm/kernel/devtree.c

echo
echo "=== 4. c_show in Serial tu dau ==="
sed -n '/seq_printf(m, "Serial/,+2p' arch/arm/kernel/setup.c
grep -n 'system_serial_low\|system_serial_high' arch/arm/kernel/setup.c | head
