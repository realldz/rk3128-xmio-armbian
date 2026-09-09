#!/usr/bin/env bash
exec > /workspace/work/v17-analysis11.log 2>&1
cd /vol/kernel-src/drivers/clocksource
echo '=== rk_timer_probe (correct match) ==='
sed -n '/rk_timer_probe(struct rk_timer/,/^}$/p' timer-rockchip.c | head -110
