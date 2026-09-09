#!/usr/bin/env bash
exec > /workspace/work/v9-analysis7.log 2>&1
K=/vol/kernel-src

echo "===== line-ending check (CRLF?) ====="
for f in drivers/tty/serial/8250/8250_dw.c drivers/tty/serial/serial_core.c \
         drivers/tty/serial/8250/8250_core.c drivers/clocksource/arm_arch_timer.c \
         drivers/clocksource/timer-rockchip.c arch/arm/mach-rockchip/platsmp.c \
         drivers/tty/serial/serial_port.c; do
  if grep -q $'\r' "$K/$f"; then echo "CRLF: $f"; else echo "LF:   $f"; fi
done

echo "===== arch_timer_of_init body ====="
F=$K/drivers/clocksource/arm_arch_timer.c
L=$(grep -n "static int __init arch_timer_of_init" $F | cut -d: -f1 | head -1)
E=$(awk -v s=$L 'NR>=s && /^}/ {print NR; exit}' $F)
echo "arch_timer_of_init $L..$E"
sed -n "${L},${E}p" $F

echo "===== 8250_core.c uart_add_one_port region ====="
sed -n '1130,1160p' $K/drivers/tty/serial/8250/8250_core.c

echo "===== rockchip_boot_secondary head (vol copy) ====="
sed -n '110,135p' $K/arch/arm/mach-rockchip/platsmp.c

echo "===== kernel build tree freshness ====="
ls -la /vol/kernel-build/arch/arm/boot/zImage 2>/dev/null
stat -c '%y %n' /vol/kernel-out/final 2>/dev/null | head -3
echo V9_ANALYSIS7_DONE
