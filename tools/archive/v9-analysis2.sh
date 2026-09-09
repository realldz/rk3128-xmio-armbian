#!/usr/bin/env bash
exec > /workspace/work/v9-analysis2.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== mainline rk3128 dtsi exists? ====="
ls $K/arch/arm/boot/dts/rockchip/ | grep -i "rk3128\|rk3126" 

echo "===== mainline rk3128.dtsi: timer + xin24m ====="
F=$K/arch/arm/boot/dts/rockchip/rk3128.dtsi
[ -f "$F" ] && grep -n "timer\|xin24m" $F | head -20

echo "===== mainline rk3128.dtsi timer node body ====="
[ -f "$F" ] && { L=$(grep -n "timer@20044000" $F | cut -d: -f1); sed -n "$((L-1)),$((L+12))p" $F; }

echo "===== rk3128-cru.h PCLK_TIMER ====="
H=$(ls $K/include/dt-bindings/clock/rk3128-cru.h 2>/dev/null)
echo "header: $H"
[ -n "$H" ] && grep -n "PCLK_TIMER\|SCLK_TIMER\|xin24m\|XIN24" $H

echo "===== xin24m in OUR decompiled v8 dts ====="
grep -n "xin24m" /workspace/work/xmio-planb-v8.dts | head -5
L=$(grep -n "xin24m {" /workspace/work/xmio-planb-v8.dts | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$L,$((L+8))p" /workspace/work/xmio-planb-v8.dts

echo "===== CRU phandle 0x46 confirm ====="
grep -n "clock-controller@20000000" /workspace/work/xmio-planb-v8.dts | head -2
L=$(grep -n "clock-controller@20000000 {" /workspace/work/xmio-planb-v8.dts | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$L,$((L+5))p" /workspace/work/xmio-planb-v8.dts

echo "===== lpj_fine setters (ARM32) ====="
grep -rn "lpj_fine" $K/arch/arm/ $K/kernel/calibrate.c $K/drivers/clocksource/ | grep -v "extern\|declare" | head -15

echo "===== calibrate_delay arm32 weak override? ====="
grep -rn "calibrate_delay" $K/arch/arm/kernel/*.c | head

echo "===== clocksource probe order: of_clksrc / timer_probe initcalls ====="
grep -n "TIMER_OF_DECLARE\|IRQCHIP_DECLARE" $K/drivers/clocksource/timer-rockchip.c
grep -n "TIMER_OF_DECLARE" $K/drivers/clocksource/arm_arch_timer.c
echo V9_ANALYSIS2_DONE
