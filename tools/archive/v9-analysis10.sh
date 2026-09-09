#!/usr/bin/env bash
exec > /workspace/work/v9-analysis10.log 2>&1
K=/vol/kernel-src

echo "===== init/main.c call order ====="
grep -n "console_init\|calibrate_delay\|time_init\|late_time_init\|mark_readonly\|rest_init" $K/init/main.c

echo "===== lpj_fine setters ====="
grep -rn "lpj_fine" $K/init/calibrate.c $K/arch/arm/kernel/*.c $K/kernel/time/*.c 2>/dev/null | grep -v "extern"

echo "===== calibrate_delay full (init/calibrate.c 255-320) ====="
sed -n '255,320p' $K/init/calibrate.c

echo "===== arm_arch_timer rating + starting ====="
grep -n "rating\|arch_timer_starting_cpu\|clockevents_config_and_register" $K/drivers/clocksource/arm_arch_timer.c | head -20

echo "===== arch/arm/kernel/time.c read_current_timer ====="
grep -n "read_current_timer\|register_current_timer_delay\|delay_timer" $K/arch/arm/kernel/time.c $K/arch/arm/lib/delay.c 2>/dev/null | head -12

echo "===== time_init ARM32 ====="
sed -n "$(grep -n '^void __init time_init' $K/arch/arm/kernel/time.c | cut -d: -f1),+12p" $K/arch/arm/kernel/time.c

echo "===== stock DTB timer nodes (hardware addresses) ====="
grep -n "timer@" /workspace/work/stock-dtbs/rk312x-stock.dts

echo "===== mainline dtsi timer + cru timer gates ====="
grep -n "timer@" $K/arch/arm/boot/dts/rockchip/rk312x.dtsi
grep -n "SCLK_TIMER" $K/include/dt-bindings/clock/rk3128-cru.h

echo "===== vendor 3.10 trees available? ====="
ls /workspace/repos/ 2>/dev/null
echo V9_ANALYSIS10_DONE
