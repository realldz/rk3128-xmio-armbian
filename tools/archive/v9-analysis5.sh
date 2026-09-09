#!/usr/bin/env bash
exec > /workspace/work/v9-analysis5.log 2>&1
K=/workspace/repos/linux-kernel-6.6-rk3128-tvbox

echo "===== printk.c get_local_clock guard (lines 55-100) ====="
sed -n '55,100p' $K/kernel/printk/printk.c

echo "===== config: PRINTK_TIME / PRINTK_CALLER / UNSTABLE_SCHED_CLOCK ====="
grep -n "CONFIG_PRINTK_TIME\|CONFIG_PRINTK_CALLER\|CONFIG_HAVE_UNSTABLE_SCHED_CLOCK\|CONFIG_NO_HZ\|CONFIG_HIGH_RES" /workspace/output/kernel/kernel.config

echo "===== main.c initcall timing source ====="
grep -n "calltime\|rettime\|usecs\|ktime\|local_clock" $K/init/main.c | head -20

echo "===== local_clock impl path (sched/clock.c) ====="
grep -n "noinline u64 local_clock\|u64 local_clock\|sched_clock_cpu\|__sched_clock_offset\|static int sched_clock_stable" $K/kernel/sched/clock.c | head -15

echo "===== sched_clock_cpu early return if unstable/stable ====="
sed -n '/^u64 notrace sched_clock_cpu/,/^}/p' $K/kernel/sched/clock.c | head -40

echo "===== is arch timer delay timer registered? (register_current_timer_delay caller) ====="
grep -n "register_current_timer_delay" $K/drivers/clocksource/arm_arch_timer.c $K/drivers/clocksource/*.c $K/arch/arm/kernel/*.c 2>/dev/null | head

echo "===== arch_timer_init on arm32: which sched_clock/clocksource, vct vs pct ====="
grep -n "arch_timer_read_counter = \|clocksource_mmio\|sched_clock_register\|set_sched_clock\|register_current_timer_delay\|arch_delay_timer" $K/drivers/clocksource/arm_arch_timer.c | head -20
echo V9_ANALYSIS5_DONE
