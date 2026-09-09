#!/usr/bin/env bash
exec > /workspace/work/v17-analysis10.log 2>&1
cd /vol/kernel-src/drivers/clocksource
echo '=== rk_timer_probe full body ==='
sed -n '/static int rk_timer_probe/,/^}/p' timer-rockchip.c | head -70
echo
echo '=== what is phandle 0x46 (context lines 395-405) ==='
sed -n '393,405p' /workspace/work/xmio-planb-v16.dts
