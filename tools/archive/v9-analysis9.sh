#!/usr/bin/env bash
exec > /workspace/work/v9-analysis9.log 2>&1
K=/vol/kernel-src

echo "===== timer-rockchip.c full 200-315 ====="
sed -n '200,315p' $K/drivers/clocksource/timer-rockchip.c

echo "===== clocksource Makefile order ====="
grep -n "arm_arch_timer\|timer-rockchip\|rockchip_timer\|ARM_ARCH_TIMER\|ROCKCHIP_TIMER" $K/drivers/clocksource/Makefile

echo "===== arm_arch_timer.c: arch_timer_register + arch_counter_register ====="
F=$K/drivers/clocksource/arm_arch_timer.c
L=$(grep -n "^static int __init arch_timer_register" $F | cut -d: -f1)
E=$(awk -v s=$L 'NR>=s && /^}/ {print NR; exit}' $F)
sed -n "${L},${E}p" $F
L2=$(grep -n "^static int __init arch_counter_register" $F | cut -d: -f1)
E2=$(awk -v s=$L2 'NR>=s && /^}/ {print NR; exit}' $F)
sed -n "${L2},${E2}p" $F

echo "===== init/calibrate.c key guards ====="
F3=$K/init/calibrate.c
grep -n "while (ticks == jiffies)\|calibrate_delay_converge\|calibrate_delay_direct\|preset_lpj\|lpj_fine\|MAX_DIRECT" $F3 | head -20

echo "===== NOTES.md recorded boot-log lines ====="
grep -n "BogoMIPS\|Calibrating\|clocksource\|sched_clock\|after 0 usecs\|0.000000" /workspace/docs/NOTES.md | head -20

echo "===== any saved user boot logs in workspace ====="
ls /workspace/work/*.log /workspace/work/*uart* /workspace/work/*boot* 2>/dev/null | head -20
grep -rln "Calibrating delay" /workspace/work /workspace/docs 2>/dev/null | head
echo V9_ANALYSIS9_DONE
