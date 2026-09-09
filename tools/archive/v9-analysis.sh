#!/usr/bin/env bash
exec > /workspace/work/v9-analysis.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== timer-rockchip.c: compatibles + probe + sched_clock ====="
F=$K/drivers/clocksource/timer-rockchip.c
[ -f "$F" ] || F=$(grep -rln "rockchip.*timer\|RK_TIMER" $K/drivers/clocksource/ | head -3 | tail -1)
echo "file: $F"
grep -n "compatible\|of_device_is\|IRQF\|sched_clock\|clockevent\|clocksource\|irq" $F | head -30
sed -n '1,40p' $F

echo "===== our timer@20044000 node (v8 dts) ====="
sed -n '1125,1160p' /workspace/work/xmio-planb-v8.dts

echo "===== stock dts timer@20044000 ====="
sed -n '2618,2650p' /workspace/work/stock-dtbs/rk312x-stock.dts

echo "===== rk3036.dtsi (mainline proven): timer + global timer nodes ====="
grep -n "timer@\|global-timer\|arm,armv7-timer\|cortex-a9-global" $K/arch/arm/boot/dts/rockchip/rk3036.dtsi
L=$(grep -n "timer@" $K/arch/arm/boot/dts/rockchip/rk3036.dtsi | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "${L},$((L+22))p" $K/arch/arm/boot/dts/rockchip/rk3036.dtsi

echo "===== rk3128.dtsi: timer nodes ====="
grep -n "timer@\|global-timer\|arm,armv7-timer" $K/arch/arm/boot/dts/rockchip/rk3128.dtsi

echo "===== config: sched clock + global timer ====="
grep -n "CLKSRC_ARM_GLOBAL_TIMER\|GLOBAL_TIMER\|SCHED_CLOCK" /workspace/output/kernel/kernel.config | head
echo V9_ANALYSIS_DONE
