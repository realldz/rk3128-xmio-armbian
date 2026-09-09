#!/usr/bin/env bash
exec > /workspace/work/v17-analysis9.log 2>&1
echo '=== periphbase / scu / global timer hints in tree ==='
grep -rn '10130000\|SCU\|global-timer\|global_timer' /vol/kernel-src/arch/arm/mach-rockchip/*.c 2>/dev/null | head -10
grep -rn 'global-timer\|global_timer' /workspace/work/stock-dtbs/rk312x-stock.dts | head -5
echo
echo '=== rk3128-cru.h timer gate indices ==='
grep -n 'TIMER' /vol/kernel-src/include/dt-bindings/clock/rk3128-cru.h | head -12
echo
echo '=== stock dts: any other timer-ish nodes (wdt/pwm not relevant) ==='
grep -n '20044020\|20044040\|20044060\|20044080\|1013[0-9a-f]*00' /workspace/work/stock-dtbs/rk312x-stock.dts | head -10
echo
echo '=== our clkevt node clocks decoding: phandle 0x46 and 0x161 ==='
grep -n 'phandle = <0x46>\|phandle = <0x161>' /workspace/work/xmio-planb-v16.dts
grep -n -B6 'phandle = <0x161>' /workspace/work/xmio-planb-v16.dts | head -10
