#!/usr/bin/env bash
F=/vol/kernel-src/arch/arm/mach-rockchip/platsmp.c
echo "=== platsmp V9DIAG occurrences ==="
grep -n "V9DIAG" $F
echo "=== aat bailout in source ==="
grep -n "V9DIAG\|v9diag_busywait" /vol/kernel-src/drivers/clocksource/arm_arch_timer.c | head
echo "=== vmlinux boot_secondary strings ==="
strings /vol/kernel-build/vmlinux | grep -c "V9DIAG: boot_secondary"
echo V9_VERIFY2_DONE
