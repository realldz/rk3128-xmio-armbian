#!/usr/bin/env bash
exec > /workspace/work/v17-analysis8.log 2>&1
echo '=== timer nodes in planb v16 dts ==='
grep -n -A6 'timer@' /workspace/work/xmio-planb-v16.dts | head -40
echo
echo '=== timer nodes in STOCK dts ==='
grep -n -A8 'timer@' /workspace/work/stock-dtbs/rk312x-stock.dts | head -60
echo
echo '=== our driver clksrc init: entry conditions + prints ==='
grep -n -B2 -A12 'rk_clksrc_init' /vol/kernel-src/drivers/clocksource/timer-rockchip.c | sed -n '1,60p'
