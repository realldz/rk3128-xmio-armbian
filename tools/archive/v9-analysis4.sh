#!/usr/bin/env bash
exec > /workspace/work/v9-analysis4.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox
D=/workspace/work/xmio-planb-v8.dts

echo "===== kernel.config: 8250 console / pm runtime / devlink ====="
grep -n "SERIAL_8250_CONSOLE\|CONFIG_PM_RUNTIME\|CONFIG_PM_GENERIC\|CONFIG_FW_DEVLINK\|CONFIG_DEVFREQ\|CONFIG_FW_LOADER" /workspace/output/kernel/kernel.config

echo "===== v8 dts: ALL nodes with rk3288-timer / rk3128-timer compatible ====="
grep -n "rk3288-timer\|rk3128-timer\|rockchip,timer" $D

echo "===== v8 dts: all timer@ node headers with clocks ====="
grep -n -A8 "timer@2004" $D | head -80

echo "===== mainline rk312x.dtsi timer nodes ====="
F=$K/arch/arm/boot/dts/rockchip/rk312x.dtsi
[ -f "$F" ] && grep -n -A10 "timer@" $F | head -60
echo "--- rk312x.dtsi exists? ---"; ls -la $K/arch/arm/boot/dts/rockchip/rk312x.dtsi 2>/dev/null || echo MISSING

echo "===== mainline rk3128.dtsi head (includes?) ====="
head -25 $K/arch/arm/boot/dts/rockchip/rk3128.dtsi

echo "===== our rk3128-xmio.dts (mainline tree, created earlier?) ====="
M=$K/arch/arm/boot/dts/rockchip/rk3128-xmio.dts
[ -f "$M" ] && { echo exists; head -20 $M; grep -n "timer\|include" $M | head; } || echo MISSING

echo "===== chieunhatnang-personal reference dtb dts (if any in workspace) ====="
ls /workspace/dtb/ 2>/dev/null | head
find /workspace/work -maxdepth 1 -name "*a26*" -o -maxdepth 1 -name "*ref*" | head

echo "===== arch_timer_of_init: cntfrq bail paths ====="
grep -n "cntfrq\|arch_timer_rate\|pr_err\|pr_warn\|return" $K/drivers/clocksource/arm_arch_timer.c | sed -n '1,40p'

echo "===== sched_clock fallback (kernel/time/sched_clock.c head) ====="
sed -n '1,60p' $K/kernel/time/sched_clock.c | grep -n "jiffy\|default\|__weak\|read_sched_clock" 
grep -n "jiffy_sched_clock_read\|sched_clock_register\|cd.read_sched_clock = " $K/kernel/time/sched_clock.c | head

echo "===== printk time source: local_clock vs sched_clock for timestamps ====="
grep -n "printk_time\|local_clock\|sched_clock" $K/kernel/printk/printk.c | head -15
echo V9_ANALYSIS4_DONE
