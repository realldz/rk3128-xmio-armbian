#!/usr/bin/env bash
exec > /workspace/work/v9-analysis3.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== rk3128-cru.h IDs 0-40 ====="
sed -n '1,45p' $K/include/dt-bindings/clock/rk3128-cru.h

echo "===== clk-rk3128.c: xin24m / id 6 ====="
grep -n "xin24m\|XIN24M" $K/drivers/clk/rockchip/clk-rk3128.c | head
sed -n '1,60p' $K/drivers/clk/rockchip/clk-rk3128.c | grep -n "6,\|xin24m" 

echo "===== timer-rockchip.c rk_timer_init body (by name or by index?) ====="
sed -n '128,205p' $K/drivers/clocksource/timer-rockchip.c

echo "===== timer-rockchip: clkevt/clksrc init fns + TIMER_OF mapping ====="
sed -n '205,320p' $K/drivers/clocksource/timer-rockchip.c

echo "===== arch/arm/lib/delay.c 55-105 (lpj_fine) ====="
sed -n '55,105p' $K/arch/arm/lib/delay.c

echo "===== CONFIG_HZ ====="
grep -n "^CONFIG_HZ" /workspace/output/kernel/kernel.config

echo "===== v8 dts: dw-apb-timer? ====="
grep -n "dw-apb-timer" /workspace/work/xmio-planb-v8.dts

echo "===== NOTES.md v8 log excerpt: clocksource/sched_clock/calibrating/smp ====="
grep -n "clocksource\|sched_clock\|Calibrating\|BogoMIPS\|Bringing up secondary\|Brought up\|rk_timer\|smpboot" NOTES.md | head -20
echo "===== NOTES.md section 29 (v8 round) ====="
L=$(grep -n "^## 29" NOTES.md | cut -d: -f1)
[ -z "$L" ] && L=$(grep -n "## 29" NOTES.md | head -1 | cut -d: -f1)
echo "section starts line $L"
[ -n "$L" ] && sed -n "${L},$((L+90))p" NOTES.md
echo V9_ANALYSIS3_DONE
