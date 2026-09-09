#!/usr/bin/env bash
exec > /workspace/work/v9-analysis8.log 2>&1
K=/vol/kernel-src

echo "===== dw8250_probe lines 645-765 ====="
sed -n '645,765p' $K/drivers/tty/serial/8250/8250_dw.c

echo "===== 8250_dw.c includes ====="
grep -n '#include' $K/drivers/tty/serial/8250/8250_dw.c

echo "===== uart_configure_port exact body ====="
F=$K/drivers/tty/serial/serial_core.c
L=$(grep -n "^static void uart_configure_port" $F | cut -d: -f1)
E=$(awk -v s=$L 'NR>=s && /^}/ {print NR; exit}' $F)
echo "span $L..$E"
sed -n "${L},${E}p" $F

echo "===== serial_port.c uart_add_one_port ====="
sed -n '130,150p' $K/drivers/tty/serial/serial_port.c

echo "===== timer-rockchip.c rk_timer_probe + clkevt + clksrc ====="
F2=$K/drivers/clocksource/timer-rockchip.c
sed -n '1,40p' $F2
grep -n "rk_timer_probe\|rk_clkevt_init\|rk_clksrc_init\|TIMER_OF_DECLARE\|clockevents_config_and_register\|clocksource_mmio_init\|sched_clock_register\|rk_timer_update_counter\|rk_timer_enable\|TIMER_CURRENT_VALUE" $F2

echo "===== calibrate_delay_converge guard ====="
F3=$K/kernel/time/sched_clock.c
grep -n "jiffy_sched_clock_read\|sched_clock_register\|postinit\|fallback" $F3 | head -12

echo "===== calibrate.c converge ====="
F4=$K/kernel/calibrate.c
grep -n "while (ticks == jiffies)\|calibrate_delay_converge\|calibrate_delay_direct\|preset_lpj\|lpj_fine" $F4 | head -12
echo V9_ANALYSIS8_DONE
